import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct GeneratedIdeaText {
    @Guide(description: "A short, catchy title for the video. At most 6 words, no hashtags.")
    var title: String
    @Guide(description: "On-screen text for the first two seconds that makes people keep watching. At most 12 words.")
    var hook: String
}

/// Uses Apple Intelligence's on-device language model (iOS 26+) to write a better title and
/// hook for each rule-based idea. Runs entirely on the phone; falls back silently when the
/// model isn't available (older phones, Apple Intelligence turned off).
@available(iOS 26.0, *)
struct OnDeviceIdeaGenerator: ContentIdeaGenerator {
    let base: any ContentIdeaGenerator

    func ideas(for clusters: [VideoCluster], query: ParsedQuery) async -> [ContentIdea] {
        var ideas = await base.ideas(for: clusters, query: query)
        guard SystemLanguageModel.default.isAvailable else { return ideas }

        for index in ideas.indices {
            let idea = ideas[index]
            let session = LanguageModelSession(instructions: """
                You help people turn videos from their own camera roll into short social media videos. \
                Be specific to what was filmed. Never invent people's names or places that aren't given.
                """)
            var details = "Detected in the clips: \(idea.cluster.topLabels(8).joined(separator: ", "))."
            if let date = idea.cluster.startDate {
                details += " Filmed: \(date.formatted(date: .abbreviated, time: .omitted))."
            }
            let prompt = """
                The user asked for: "\(query.raw)".
                We found \(idea.clips.count) matching clips for a \(Int(idea.totalDuration))-second \(idea.format.displayName) video \
                in the style "\(idea.theme.title)".
                \(details)
                Write a title and an opening hook.
                """
            if let response = try? await session.respond(to: prompt, generating: GeneratedIdeaText.self) {
                ideas[index].title = response.content.title
                ideas[index].hook = response.content.hook
            }
        }
        return ideas
    }
}
#endif

enum AppleIntelligence {
    /// True only on phones that have Apple Intelligence turned on and ready
    /// (iPhone 15 Pro and newer, iOS 26+, supported language/region).
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }
}

enum IdeaGenerators {
    /// Every phone gets the template writer; Apple Intelligence only polishes on top of it.
    static func make(useAppleIntelligence: Bool, places: (any PlaceNaming)?) -> any ContentIdeaGenerator {
        let base = RuleBasedIdeaGenerator(places: places)
        #if canImport(FoundationModels)
        if useAppleIntelligence, #available(iOS 26.0, *), AppleIntelligence.isAvailable {
            return OnDeviceIdeaGenerator(base: base)
        }
        #endif
        return base
    }
}
