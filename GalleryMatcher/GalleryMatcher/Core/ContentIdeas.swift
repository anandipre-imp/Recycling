import Foundation

/// A video the app suggests making, with the clips to make it from.
struct ContentIdea: Identifiable, Hashable {
    let id: String
    var title: String
    var hook: String
    let theme: Theme
    let format: ContentFormat
    let cluster: VideoCluster
    let clips: [PlannedClip]

    var totalDuration: Double { clips.reduce(0) { $0 + $1.duration } }
}

/// Turns groups of matching videos into content ideas.
///
/// `RuleBasedIdeaGenerator` works on every iPhone. `OnDeviceIdeaGenerator` layers Apple
/// Intelligence on top when the phone has it. A cloud LLM can be plugged in the same way.
protocol ContentIdeaGenerator {
    func ideas(for clusters: [VideoCluster], query: ParsedQuery) async -> [ContentIdea]
}

/// Turns coordinates into a short place name ("Lisbon"). Optional; ideas just skip
/// place-based titles when it returns nil.
protocol PlaceNaming {
    func placeName(latitude: Double, longitude: Double) async -> String?
}

struct RuleBasedIdeaGenerator: ContentIdeaGenerator {
    var maxIdeas = 6
    var targetDuration: Double = 30
    var places: (any PlaceNaming)?

    func ideas(for clusters: [VideoCluster], query: ParsedQuery) async -> [ContentIdea] {
        var ideas: [ContentIdea] = []
        for cluster in clusters.prefix(maxIdeas) {
            var place: String?
            if let places, let center = cluster.center {
                place = await places.placeName(latitude: center.latitude, longitude: center.longitude)
            }
            ideas.append(idea(for: cluster, query: query, place: place))
        }
        return ideas
    }

    func idea(for cluster: VideoCluster, query: ParsedQuery, place: String? = nil) -> ContentIdea {
        let theme = Self.theme(for: cluster, preferring: query.themes)
        let clips = ClipPlanner.plan(cluster.members, targetDuration: targetDuration)
        let context = IdeaWriter.Context(
            theme: theme,
            place: place,
            startDate: cluster.startDate,
            clipCount: clips.count,
            hasPeople: cluster.members.contains { $0.maxFaceCount > 0 },
            seed: IdeaWriter.seed(for: cluster.members.map(\.id))
        )
        return ContentIdea(
            id: cluster.id,
            title: IdeaWriter.title(context),
            hook: IdeaWriter.hook(context),
            theme: theme,
            format: query.format,
            cluster: cluster,
            clips: clips
        )
    }

    /// The theme whose labels carry the most confidence across the cluster.
    /// Themes the user asked for get a boost so "pet reel" doesn't come back as "Nature".
    static func theme(for cluster: VideoCluster, preferring preferred: [Theme]) -> Theme {
        var best = Themes.fallback
        var bestScore: Float = 0
        for theme in Themes.all {
            var score: Float = 0
            for member in cluster.members {
                for label in member.labels where theme.matches(label: label.name) {
                    score += label.confidence
                }
            }
            if preferred.contains(theme) { score *= 2 }
            if score > bestScore {
                best = theme
                bestScore = score
            }
        }
        return best
    }
}
