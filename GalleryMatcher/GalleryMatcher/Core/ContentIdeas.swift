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
/// The default is rule-based; `OnDeviceIdeaGenerator` layers Apple's on-device language
/// model on top when the phone supports it. A cloud LLM can be plugged in the same way.
protocol ContentIdeaGenerator {
    func ideas(for clusters: [VideoCluster], query: ParsedQuery) async -> [ContentIdea]
}

struct RuleBasedIdeaGenerator: ContentIdeaGenerator {
    var maxIdeas = 6
    var targetDuration: Double = 30

    func ideas(for clusters: [VideoCluster], query: ParsedQuery) async -> [ContentIdea] {
        clusters.prefix(maxIdeas).map { idea(for: $0, query: query) }
    }

    func idea(for cluster: VideoCluster, query: ParsedQuery) -> ContentIdea {
        let theme = Self.theme(for: cluster, preferring: query.themes)
        var title = theme.title
        if let date = cluster.startDate {
            title += " · " + date.formatted(.dateTime.month(.abbreviated).year())
        }
        return ContentIdea(
            id: cluster.id,
            title: title,
            hook: theme.hook,
            theme: theme,
            format: query.format,
            cluster: cluster,
            clips: ClipPlanner.plan(cluster.members, targetDuration: targetDuration)
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
