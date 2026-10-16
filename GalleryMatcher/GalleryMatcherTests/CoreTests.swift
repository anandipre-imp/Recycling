import XCTest
@testable import GalleryMatcher

private func video(
    _ id: String,
    labels: [String: Float],
    minutesFromStart: Double = 0,
    duration: Double = 10,
    print: [Float] = [],
    lat: Double? = nil,
    lon: Double? = nil
) -> VideoAnalysis {
    VideoAnalysis(
        id: id,
        creationDate: Date(timeIntervalSince1970: 1_750_000_000 + minutesFromStart * 60),
        duration: duration,
        latitude: lat,
        longitude: lon,
        labels: labels.map { VideoLabel(name: $0.key, confidence: $0.value) }.sorted { $0.confidence > $1.confidence },
        featurePrint: print,
        highlightTime: duration / 2
    )
}

final class QueryParserTests: XCTestCase {
    func testDropsFormatWordsAndPicksVertical() {
        let query = QueryParser.parse("Beach trip reel")
        XCTAssertEqual(query.terms, ["beach", "trip"])
        XCTAssertEqual(query.format, .vertical)
        XCTAssertTrue(query.themes.contains { $0.name == "travel" })
        XCTAssertTrue(query.themes.contains { $0.name == "beach" })
    }

    func testYouTubeMeansHorizontal() {
        XCTAssertEqual(QueryParser.parse("YouTube travel vlog").format, .horizontal)
    }

    func testOnlyStopwordsGivesNoTerms() {
        XCTAssertTrue(QueryParser.parse("make me a reel").terms.isEmpty)
    }
}

final class SimilarityTests: XCTestCase {
    let similarity = LexicalSimilarity()

    func testExactAndMultiWordLabels() {
        XCTAssertEqual(similarity.similarity(term: "dog", label: "dog"), 1)
        XCTAssertEqual(similarity.similarity(term: "sunset", label: "sunset sunrise"), 1)
    }

    func testPlurals() {
        XCTAssertEqual(similarity.similarity(term: "dogs", label: "dog"), 0.95)
        XCTAssertEqual(similarity.similarity(term: "puppies", label: "puppy"), 0.95)
    }

    func testThemeExpansion() {
        XCTAssertEqual(similarity.similarity(term: "trip", label: "beach"), 0.75)
        XCTAssertEqual(similarity.similarity(term: "trip", label: "pizza"), 0)
    }
}

final class QueryMatcherTests: XCTestCase {
    let library = [
        video("beach", labels: ["beach": 0.9, "sky": 0.6]),
        video("dog", labels: ["dog": 0.95, "grass": 0.5]),
        video("pizza", labels: ["pizza": 0.8, "food": 0.9]),
    ]

    func testFindsVideosThroughThemes() {
        let results = QueryMatcher().rank(library, query: QueryParser.parse("vacation reel"))
        XCTAssertEqual(results.map(\.id), ["beach"])
    }

    func testUnknownWordsDoNotZeroTheScore() {
        let results = QueryMatcher().rank(library, query: QueryParser.parse("dog xyzzy"))
        XCTAssertEqual(results.first?.id, "dog")
        XCTAssertEqual(results.first?.score ?? 0, 0.95, accuracy: 0.001)
    }

    func testNoMatches() {
        XCTAssertTrue(QueryMatcher().rank(library, query: QueryParser.parse("snowboarding")).isEmpty)
    }
}

final class ClustererTests: XCTestCase {
    func testGroupsByLookAndByEvent() {
        let videos = [
            // Look alike, filmed months apart.
            video("a", labels: [:], minutesFromStart: 0, print: [1, 0, 0]),
            video("b", labels: [:], minutesFromStart: 200_000, print: [0.95, 0.05, 0]),
            // Look different but same place, 20 minutes apart.
            video("c", labels: [:], minutesFromStart: 500_000, print: [0, 1, 0], lat: 40.0, lon: -73.0),
            video("d", labels: [:], minutesFromStart: 500_020, print: [0, 0, 1], lat: 40.001, lon: -73.001),
            // Same time window but 50 km away.
            video("e", labels: [:], minutesFromStart: 500_010, print: [1, 1, -1], lat: 40.5, lon: -73.0),
        ]
        let groups = Clusterer().cluster(videos).map { Set($0.members.map(\.id)) }
        XCTAssertTrue(groups.contains(["a", "b"]))
        XCTAssertTrue(groups.contains(["c", "d"]))
        XCTAssertTrue(groups.contains(["e"]))
    }

    func testTopLabelsSkipGenericOnes() {
        let cluster = VideoCluster(members: [
            video("1", labels: ["structure": 0.99, "beach": 0.8]),
            video("2", labels: ["beach": 0.7, "sky": 0.6]),
        ])
        XCTAssertEqual(cluster.topLabels(2), ["beach", "sky"])
    }
}

final class ClipPlannerTests: XCTestCase {
    func testClipsAreChronologicalAndInsideTheVideo() {
        let videos = [
            video("late", labels: [:], minutesFromStart: 10, duration: 2),
            video("early", labels: [:], minutesFromStart: 0, duration: 60),
        ]
        let clips = ClipPlanner.plan(videos, targetDuration: 6, maxClipLength: 3)
        XCTAssertEqual(clips.map(\.videoID), ["early", "late"])
        XCTAssertEqual(clips[0].duration, 3)
        XCTAssertEqual(clips[0].start, 28.5)
        // A 2 s video can only give 2 s, starting at 0.
        XCTAssertEqual(clips[1].duration, 2)
        XCTAssertEqual(clips[1].start, 0)
    }

    func testRespectsTargetDuration() {
        let videos = (0..<40).map { video("\($0)", labels: [:], minutesFromStart: Double($0)) }
        let clips = ClipPlanner.plan(videos, targetDuration: 30, minClipLength: 1.5, maxClipLength: 3)
        XCTAssertEqual(clips.count, 20)
        XCTAssertLessThanOrEqual(clips.reduce(0) { $0 + $1.duration }, 30.0001)
    }
}

final class IdeaTests: XCTestCase {
    func testThemePrefersWhatTheUserAskedFor() {
        let cluster = VideoCluster(members: [
            video("1", labels: ["dog": 0.6, "grass": 0.9, "tree": 0.8]),
            video("2", labels: ["dog": 0.7, "forest": 0.8]),
        ])
        XCTAssertEqual(RuleBasedIdeaGenerator.theme(for: cluster, preferring: []).name, "nature")
        let pets = QueryParser.parse("dog reel").themes
        XCTAssertEqual(RuleBasedIdeaGenerator.theme(for: cluster, preferring: pets).name, "pets")
    }

    func testAnalysisRoundTripsThroughJSON() throws {
        let original = video("x", labels: ["beach": 0.5], print: [0.25, -1, 3.5])
        let decoded = try JSONDecoder().decode(VideoAnalysis.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }
}
