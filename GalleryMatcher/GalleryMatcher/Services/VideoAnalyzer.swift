import AVFoundation
import Photos
import Vision

enum VideoAnalysisError: Error {
    case noFrames
}

/// Looks at a video with Apple's on-device Vision models and produces a `VideoAnalysis`.
///
/// Nothing leaves the phone: a handful of frames are sampled, and for each one we
/// get scene/object labels, a visual fingerprint (feature print) and a face count.
struct VideoAnalyzer: Sendable {
    var framesPerVideo = 5
    var minimumLabelConfidence: Float = 0.25
    var maxLabels = 15

    func analyze(_ asset: PHAsset, library: PhotoLibraryService) async throws -> VideoAnalysis {
        let avAsset = try await library.avAsset(for: asset, quality: .analysis)
        let duration = asset.duration

        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var bestLabels: [String: Float] = [:]
        var prints: [[Float]] = []
        var maxFaces = 0
        var highlightTime = duration / 2
        var highlightScore: Float = -1

        for seconds in sampleTimes(duration: duration) {
            try Task.checkCancellation()
            guard let frame = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)),
                  let result = try? analyzeFrame(frame.image)
            else { continue }

            for (name, confidence) in result.labels {
                bestLabels[name] = max(bestLabels[name] ?? 0, confidence)
            }
            if !result.featurePrint.isEmpty { prints.append(result.featurePrint) }
            maxFaces = max(maxFaces, result.faceCount)

            // "Interesting" = lots of confident content, with a bonus for faces.
            let score = result.labels.prefix(3).reduce(0) { $0 + $1.1 } + 0.3 * Float(min(result.faceCount, 3))
            if score > highlightScore {
                highlightScore = score
                highlightTime = frame.actualTime.seconds
            }
        }

        guard !bestLabels.isEmpty || !prints.isEmpty else { throw VideoAnalysisError.noFrames }

        let labels = bestLabels
            .map { VideoLabel(name: $0.key, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxLabels)

        return VideoAnalysis(
            id: asset.localIdentifier,
            creationDate: asset.creationDate,
            duration: duration,
            latitude: asset.location?.coordinate.latitude,
            longitude: asset.location?.coordinate.longitude,
            labels: Array(labels),
            featurePrint: VectorMath.mean(prints),
            maxFaceCount: maxFaces,
            highlightTime: highlightTime
        )
    }

    /// Evenly spaced, avoiding the very first and last frames (often black or shaky).
    private func sampleTimes(duration: Double) -> [Double] {
        guard duration > 0 else { return [0] }
        let n = max(1, framesPerVideo)
        return (0..<n).map { duration * (Double($0) + 0.5) / Double(n) }
    }

    private struct FrameResult {
        var labels: [(String, Float)]
        var featurePrint: [Float]
        var faceCount: Int
    }

    private func analyzeFrame(_ image: CGImage) throws -> FrameResult {
        let classify = VNClassifyImageRequest()
        let featurePrint = VNGenerateImageFeaturePrintRequest()
        let faces = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([classify, featurePrint, faces])

        let labels = (classify.results ?? [])
            .filter { $0.confidence >= minimumLabelConfidence }
            .sorted { $0.confidence > $1.confidence }
            .map { (LabelText.normalize($0.identifier), $0.confidence) }

        return FrameResult(
            labels: labels,
            featurePrint: featurePrint.results?.first.map(Self.floats(from:)) ?? [],
            faceCount: faces.results?.count ?? 0
        )
    }

    static func floats(from observation: VNFeaturePrintObservation) -> [Float] {
        switch observation.elementType {
        case .float:
            return observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        case .double:
            return observation.data.withUnsafeBytes { $0.bindMemory(to: Double.self).map { Float($0) } }
        default:
            return []
        }
    }
}
