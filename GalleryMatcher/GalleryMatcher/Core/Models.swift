import CoreGraphics
import Foundation

/// One thing the AI recognised in a video, e.g. "beach" at 0.92 confidence.
struct VideoLabel: Codable, Hashable {
    var name: String
    var confidence: Float
}

/// Everything we learn about a single video. Created once per video by `VideoAnalyzer`
/// and cached on disk, so the library only has to be scanned once.
struct VideoAnalysis: Codable, Hashable, Identifiable {
    /// Bump this when the analyzer changes so old results get re-analyzed.
    static let currentVersion = 1

    /// The `PHAsset.localIdentifier` of the video.
    let id: String
    var creationDate: Date?
    var duration: Double
    var latitude: Double?
    var longitude: Double?
    /// Scene/object labels, strongest first.
    var labels: [VideoLabel]
    /// Visual "fingerprint" (averaged Vision feature print). Similar-looking videos have similar vectors.
    var featurePrint: [Float]
    var maxFaceCount: Int
    /// The most interesting moment (seconds), used when cutting a clip out of this video.
    var highlightTime: Double
    var analyzerVersion: Int

    init(
        id: String,
        creationDate: Date? = nil,
        duration: Double,
        latitude: Double? = nil,
        longitude: Double? = nil,
        labels: [VideoLabel],
        featurePrint: [Float] = [],
        maxFaceCount: Int = 0,
        highlightTime: Double = 0,
        analyzerVersion: Int = VideoAnalysis.currentVersion
    ) {
        self.id = id
        self.creationDate = creationDate
        self.duration = duration
        self.latitude = latitude
        self.longitude = longitude
        self.labels = labels
        self.featurePrint = featurePrint
        self.maxFaceCount = maxFaceCount
        self.highlightTime = highlightTime
        self.analyzerVersion = analyzerVersion
    }

    func confidence(for label: String) -> Float {
        labels.first { $0.name == label }?.confidence ?? 0
    }

    // The feature print is stored as raw bytes (base64 in JSON) rather than an array of
    // numbers, which keeps the cache file roughly 3x smaller.
    private enum CodingKeys: String, CodingKey {
        case id, creationDate, duration, latitude, longitude, labels, featurePrint, maxFaceCount, highlightTime, analyzerVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        creationDate = try c.decodeIfPresent(Date.self, forKey: .creationDate)
        duration = try c.decode(Double.self, forKey: .duration)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        labels = try c.decode([VideoLabel].self, forKey: .labels)
        let printData = try c.decode(Data.self, forKey: .featurePrint)
        featurePrint = printData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        maxFaceCount = try c.decode(Int.self, forKey: .maxFaceCount)
        highlightTime = try c.decode(Double.self, forKey: .highlightTime)
        analyzerVersion = try c.decode(Int.self, forKey: .analyzerVersion)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(creationDate, forKey: .creationDate)
        try c.encode(duration, forKey: .duration)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
        try c.encode(labels, forKey: .labels)
        try c.encode(featurePrint.withUnsafeBufferPointer { Data(buffer: $0) }, forKey: .featurePrint)
        try c.encode(maxFaceCount, forKey: .maxFaceCount)
        try c.encode(highlightTime, forKey: .highlightTime)
        try c.encode(analyzerVersion, forKey: .analyzerVersion)
    }
}

/// Output shape of the finished video.
enum ContentFormat: String, Codable, CaseIterable, Hashable {
    /// 9:16 — Reels, TikTok, Shorts, Stories.
    case vertical
    /// 16:9 — YouTube.
    case horizontal

    var renderSize: CGSize {
        switch self {
        case .vertical: CGSize(width: 1080, height: 1920)
        case .horizontal: CGSize(width: 1920, height: 1080)
        }
    }

    var displayName: String {
        switch self {
        case .vertical: "9:16"
        case .horizontal: "16:9"
        }
    }
}

enum LabelText {
    /// Vision identifiers look like "sunset_sunrise"; we store them as "sunset sunrise".
    static func normalize(_ identifier: String) -> String {
        identifier.lowercased().replacingOccurrences(of: "_", with: " ")
    }

    /// Labels too generic to be worth showing as a tag.
    static let generic: Set<String> = [
        "structure", "material", "textile", "outdoor", "indoor", "liquid", "consumable", "machine",
        "conveyance", "document", "screenshot", "wood processed", "interior room",
    ]
}
