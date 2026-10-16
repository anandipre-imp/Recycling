import Foundation

/// A group of videos that belong together — same scene, same day, same place.
struct VideoCluster: Identifiable, Hashable {
    /// Members in chronological order.
    let members: [VideoAnalysis]

    init(members: [VideoAnalysis]) {
        self.members = members.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    var id: String { members.map(\.id).joined(separator: ",") }
    var startDate: Date? { members.compactMap(\.creationDate).min() }
    var endDate: Date? { members.compactMap(\.creationDate).max() }
    var totalDuration: Double { members.reduce(0) { $0 + $1.duration } }

    /// The labels that best describe the group as a whole.
    func topLabels(_ count: Int = 5) -> [String] {
        var weight: [String: Float] = [:]
        for member in members {
            for label in member.labels where !LabelText.generic.contains(label.name) {
                weight[label.name, default: 0] += label.confidence
            }
        }
        return weight.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(count)
            .map(\.key)
    }
}

/// Groups videos by how they look and when/where they were filmed.
///
/// Two videos are linked if they look alike (feature-print similarity), or if they were
/// shot close together in time and place. Linked videos end up in the same cluster
/// (union-find), so a chain A~B~C forms one group even if A and C differ.
struct Clusterer {
    /// Cosine similarity of feature prints above which two videos count as the same scene.
    var visualThreshold: Float = 0.8
    /// Videos within this many seconds of each other may be the same event...
    var eventWindow: TimeInterval = 3 * 3600
    /// ...provided they were also shot within this distance (when both have a location).
    var eventRadiusMeters: Double = 1000
    /// When location is missing, require videos to be this close in time instead.
    var eventWindowWithoutLocation: TimeInterval = 3600

    func cluster(_ videos: [VideoAnalysis]) -> [VideoCluster] {
        var parent = Array(videos.indices)

        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i {
                parent[i] = parent[parent[i]]
                i = parent[i]
            }
            return i
        }

        for i in videos.indices {
            for j in videos.indices where j > i && belongTogether(videos[i], videos[j]) {
                parent[root(j)] = root(i)
            }
        }

        var groups: [Int: [VideoAnalysis]] = [:]
        for i in videos.indices {
            groups[root(i), default: []].append(videos[i])
        }

        return groups.values
            .map(VideoCluster.init(members:))
            .sorted {
                $0.members.count != $1.members.count
                    ? $0.members.count > $1.members.count
                    : ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast)
            }
    }

    func belongTogether(_ a: VideoAnalysis, _ b: VideoAnalysis) -> Bool {
        if VectorMath.cosine(a.featurePrint, b.featurePrint) >= visualThreshold { return true }

        guard let dateA = a.creationDate, let dateB = b.creationDate else { return false }
        let gap = abs(dateA.timeIntervalSince(dateB))

        if let latA = a.latitude, let lonA = a.longitude, let latB = b.latitude, let lonB = b.longitude {
            return gap <= eventWindow
                && VectorMath.metersBetween(lat1: latA, lon1: lonA, lat2: latB, lon2: lonB) <= eventRadiusMeters
        }
        return gap <= eventWindowWithoutLocation
    }
}
