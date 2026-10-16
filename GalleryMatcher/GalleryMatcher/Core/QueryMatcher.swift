import Foundation

/// What the user typed, broken into the parts we act on.
struct ParsedQuery: Hashable {
    let raw: String
    /// Content words, e.g. "beach trip reel" -> ["beach", "trip"].
    let terms: [String]
    let format: ContentFormat
    /// Themes the user explicitly asked for ("trip" -> travel).
    let themes: [Theme]
}

enum QueryParser {
    /// Words that describe the *output* rather than what should be in it.
    static let stopwords: Set<String> = [
        "a", "an", "the", "of", "my", "me", "i", "we", "our", "with", "and", "or", "for", "to", "in", "on", "at", "from",
        "some", "all", "any", "video", "videos", "clip", "clips", "reel", "reels", "tiktok", "tiktoks", "short", "shorts",
        "youtube", "content", "make", "create", "want", "need", "montage", "compilation", "recap", "edit", "vlog", "story",
        "stories", "instagram", "insta", "post", "about", "that", "this", "these", "like", "kind", "type", "please",
        "show", "find", "best", "moments", "highlights", "landscape", "horizontal", "vertical", "widescreen",
    ]

    static let verticalWords: Set<String> = ["reel", "reels", "tiktok", "tiktoks", "short", "shorts", "story", "stories", "instagram", "insta", "vertical"]
    static let horizontalWords: Set<String> = ["youtube", "landscape", "horizontal", "widescreen"]

    static func parse(_ query: String) -> ParsedQuery {
        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var terms: [String] = []
        for word in words where !stopwords.contains(word) && !terms.contains(word) {
            terms.append(word)
        }

        let format: ContentFormat = words.contains(where: horizontalWords.contains) && !words.contains(where: verticalWords.contains)
            ? .horizontal : .vertical

        var themes: [Theme] = []
        for term in terms {
            for theme in Themes.triggered(by: term) where !themes.contains(theme) {
                themes.append(theme)
            }
        }
        return ParsedQuery(raw: query, terms: terms, format: format, themes: themes)
    }
}

/// How well a query word matches a video label, in [0, 1].
protocol TermSimilarity {
    func similarity(term: String, label: String) -> Double
}

/// Exact, plural-tolerant and theme-based matching. Works offline with no model.
struct LexicalSimilarity: TermSimilarity {
    func similarity(term: String, label: String) -> Double {
        let labelWords = label.split(separator: " ").map(String.init)
        if label == term || labelWords.contains(term) { return 1 }

        let stem = Self.stem(term)
        if labelWords.contains(where: { Self.stem($0) == stem }) { return 0.95 }

        let themes = Themes.triggered(by: term) + (stem == term ? [] : Themes.triggered(by: stem))
        if themes.contains(where: { $0.matches(label: label) }) { return 0.75 }
        return 0
    }

    /// Very small English stemmer: "dogs" -> "dog", "puppies" -> "puppy".
    static func stem(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }
}

struct ScoredVideo: Hashable, Identifiable {
    let video: VideoAnalysis
    let score: Double
    var id: String { video.id }
}

struct QueryMatcher {
    var similarity: any TermSimilarity = LexicalSimilarity()
    /// Videos scoring below this are dropped.
    var minimumScore = 0.2
    var limit = 200

    /// Ranks videos by how well their labels cover the query terms.
    ///
    /// Each term contributes the best (label confidence x term similarity) found in a video;
    /// the video's score is the mean over terms. Terms that match nothing anywhere in the
    /// library (typos, words we don't understand) are ignored instead of zeroing every score.
    func rank(_ videos: [VideoAnalysis], query: ParsedQuery) -> [ScoredVideo] {
        guard !query.terms.isEmpty else { return [] }

        let table: [[Double]] = videos.map { video in
            query.terms.map { term in
                video.labels.reduce(0) { best, label in
                    max(best, Double(label.confidence) * similarity.similarity(term: term, label: label.name))
                }
            }
        }

        let activeTerms = query.terms.indices.filter { i in table.contains { $0[i] > 0 } }
        guard !activeTerms.isEmpty else { return [] }

        var scored: [ScoredVideo] = []
        for (video, row) in zip(videos, table) {
            let score = activeTerms.reduce(0) { $0 + row[$1] } / Double(activeTerms.count)
            if score >= minimumScore {
                scored.append(ScoredVideo(video: video, score: score))
            }
        }
        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(limit))
    }
}
