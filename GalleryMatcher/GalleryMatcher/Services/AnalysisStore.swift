import Foundation

/// Persists analysis results so each video is only analyzed once.
/// Stored in Application Support, which stays on the device.
actor AnalysisStore {
    private let fileURL: URL

    init(fileName: String = "video-analyses.json") {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(fileName)
    }

    func load() -> [String: VideoAnalysis] {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([VideoAnalysis].self, from: data)
        else { return [:] }
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    func save(_ analyses: [String: VideoAnalysis]) {
        do {
            let data = try JSONEncoder().encode(Array(analyses.values))
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("AnalysisStore: failed to save – \(error)")
        }
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
