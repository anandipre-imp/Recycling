import NaturalLanguage

/// Adds meaning-based matching on top of `LexicalSimilarity` using Apple's built-in
/// English word embeddings, so "puppy" can match a "dog" label and "seaside" a "beach".
final class EmbeddingSimilarity: TermSimilarity {
    private let lexical = LexicalSimilarity()
    private let embedding = NLEmbedding.wordEmbedding(for: .english)
    private var cache: [String: Double] = [:]

    /// Embedding similarity (1 - cosine distance) needed before we count it as a match.
    var threshold = 0.65
    /// Embedding matches are weaker evidence than exact/theme matches.
    var weight = 0.7

    func similarity(term: String, label: String) -> Double {
        let key = term + "|" + label
        if let cached = cache[key] { return cached }

        var score = lexical.similarity(term: term, label: label)
        if score < 0.75, let embedding {
            for word in label.split(separator: " ") {
                let semantic = 1 - embedding.distance(between: term, and: String(word))
                if semantic >= threshold {
                    score = max(score, semantic * weight)
                }
            }
        }
        cache[key] = score
        return score
    }
}
