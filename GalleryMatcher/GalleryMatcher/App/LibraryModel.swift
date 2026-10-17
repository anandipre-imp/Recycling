import Observation
import Photos
import UIKit

struct TagCount: Hashable {
    let name: String
    let videos: Int
}

@MainActor
@Observable
final class LibraryModel {
    enum Access {
        case notDetermined, denied, limited, full

        init(_ status: PHAuthorizationStatus) {
            switch status {
            case .authorized: self = .full
            case .limited: self = .limited
            case .notDetermined: self = .notDetermined
            default: self = .denied
            }
        }

        var canRead: Bool { self == .full || self == .limited }
    }

    enum ExportState: Equatable {
        case idle
        case exporting(ideaID: String)
        case saved(ideaID: String)
        case failed(ideaID: String, message: String)
    }

    private(set) var access: Access
    private(set) var totalVideos = 0
    private(set) var analyses: [String: VideoAnalysis] = [:]
    private(set) var isIndexing = false
    private(set) var lastQuery: ParsedQuery?
    private(set) var ideas: [ContentIdea] = []
    private(set) var matchCount = 0
    private(set) var isSearching = false
    private(set) var exportState: ExportState = .idle
    /// Whether the current ideas were polished by Apple Intelligence (for the UI label).
    private(set) var ideasUsedAppleIntelligence = false

    /// Lets people with Apple Intelligence still choose the standard writer — and lets us
    /// test what phones without it see.
    var useAppleIntelligence = UserDefaults.standard.object(forKey: "useAppleIntelligence") as? Bool ?? true {
        didSet { UserDefaults.standard.set(useAppleIntelligence, forKey: "useAppleIntelligence") }
    }
    var usePlaceNames = UserDefaults.standard.object(forKey: "usePlaceNames") as? Bool ?? true {
        didSet { UserDefaults.standard.set(usePlaceNames, forKey: "usePlaceNames") }
    }
    let appleIntelligenceAvailable = AppleIntelligence.isAvailable

    private let library = PhotoLibraryService()
    private let store = AnalysisStore()
    private let analyzer = VideoAnalyzer()
    private let matcher = QueryMatcher(similarity: EmbeddingSimilarity())
    private let clusterer = Clusterer()
    private let placeNamer = PlaceNamer()

    private var assetsByID: [String: PHAsset] = [:]
    private var orderedIDs: [String] = []
    private var indexingTask: Task<Void, Never>?
    private var didLoadCache = false

    init() {
        access = Access(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    var analyzedCount: Int { orderedIDs.filter { analyses[$0] != nil }.count }

    // MARK: Library access & indexing

    func requestAccess() async {
        access = Access(await library.requestAuthorization())
        await refresh()
    }

    /// Re-reads the photo library and analyzes anything new. Cheap to call repeatedly.
    func refresh() async {
        access = Access(library.authorizationStatus)
        guard access.canRead else { return }

        if !didLoadCache {
            analyses = await store.load()
            didLoadCache = true
        }

        let assets = library.fetchVideos()
        assetsByID = Dictionary(assets.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        orderedIDs = assets.map(\.localIdentifier)
        totalVideos = assets.count
        startIndexing()
    }

    private func startIndexing() {
        guard indexingTask == nil else { return }
        let pending = orderedIDs.filter { analyses[$0]?.analyzerVersion != VideoAnalysis.currentVersion }
        guard !pending.isEmpty else { return }
        indexingTask = Task { await index(pending) }
    }

    private func index(_ ids: [String]) async {
        isIndexing = true
        let analyzer = analyzer
        let library = library
        var iterator = ids.makeIterator()
        var lastSave = Date()

        func nextAsset() -> PHAsset? {
            while let id = iterator.next() {
                if let asset = assetsByID[id] { return asset }
            }
            return nil
        }

        await withTaskGroup(of: VideoAnalysis?.self) { group in
            // Two at a time keeps the phone responsive and avoids flooding iCloud downloads.
            for _ in 0..<2 {
                guard let asset = nextAsset() else { break }
                group.addTask { try? await analyzer.analyze(asset, library: library) }
            }
            while let result = await group.next() {
                if let result { analyses[result.id] = result }
                if Date().timeIntervalSince(lastSave) > 20 {
                    await store.save(analyses)
                    lastSave = Date()
                }
                if Task.isCancelled { group.cancelAll(); break }
                if let asset = nextAsset() {
                    group.addTask { try? await analyzer.analyze(asset, library: library) }
                }
            }
        }

        await store.save(analyses)
        isIndexing = false
        indexingTask = nil
    }

    func resetAnalysis() async {
        indexingTask?.cancel()
        await indexingTask?.value
        analyses = [:]
        await store.reset()
        await refresh()
    }

    // MARK: Search & ideas

    func search(_ text: String) async {
        let query = QueryParser.parse(text)
        guard !query.terms.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }

        let visible = orderedIDs.compactMap { analyses[$0] }
        let ranked = matcher.rank(visible, query: query)
        let scoreByID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.id, $0.score) })

        func groupScore(_ cluster: VideoCluster) -> Double {
            cluster.members.reduce(0) { $0 + (scoreByID[$1.id] ?? 0) }
        }

        var clusters = clusterer.cluster(ranked.map(\.video))
            .filter { $0.members.count >= 2 }
            .sorted { groupScore($0) > groupScore($1) }

        // Always offer a "best of" built from the strongest matches across the whole library.
        if ranked.count >= 3 {
            let bestOf = VideoCluster(members: Array(ranked.prefix(12).map(\.video)))
            if !clusters.contains(where: { $0.id == bestOf.id }) {
                clusters.insert(bestOf, at: 0)
            }
        }

        lastQuery = query
        matchCount = ranked.count
        let generator = IdeaGenerators.make(
            useAppleIntelligence: useAppleIntelligence,
            places: usePlaceNames ? (placeNamer as any PlaceNaming) : nil
        )
        ideas = await generator.ideas(for: clusters, query: query)
        ideasUsedAppleIntelligence = useAppleIntelligence && appleIntelligenceAvailable
    }

    /// Groups across the most recent videos, for browsing without a query.
    func discoveredGroups(limit: Int = 400) -> [VideoCluster] {
        let recent = orderedIDs.prefix(limit).compactMap { analyses[$0] }
        return clusterer.cluster(recent).filter { $0.members.count >= 3 }
    }

    /// The most common tags across the library, for the Library tab.
    func topTags(_ count: Int = 30) -> [TagCount] {
        var counts: [String: Int] = [:]
        for analysis in analyses.values {
            for label in analysis.labels where label.confidence >= 0.4 && !LabelText.generic.contains(label.name) {
                counts[label.name, default: 0] += 1
            }
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(count)
            .map { TagCount(name: $0.key, videos: $0.value) }
    }

    // MARK: Making the video

    func makeVideo(_ idea: ContentIdea) async {
        exportState = .exporting(ideaID: idea.id)
        let clips = idea.clips.compactMap { clip in assetsByID[clip.videoID].map { (asset: $0, clip: clip) } }
        do {
            let url = try await CompilationExporter(library: library).export(clips, format: idea.format)
            defer { try? FileManager.default.removeItem(at: url) }
            try await library.saveVideo(at: url)
            exportState = .saved(ideaID: idea.id)
        } catch {
            exportState = .failed(ideaID: idea.id, message: error.localizedDescription)
        }
    }

    func thumbnail(for videoID: String, size: CGSize) async -> UIImage? {
        guard let asset = assetsByID[videoID] else { return nil }
        return await library.thumbnail(for: asset, size: size)
    }
}
