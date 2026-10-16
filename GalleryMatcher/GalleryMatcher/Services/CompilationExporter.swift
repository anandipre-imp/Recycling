import AVFoundation
import Photos

enum CompilationError: LocalizedError {
    case nothingToExport
    case exportFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .nothingToExport: "None of the selected clips could be loaded."
        case .exportFailed(let error): "Export failed: \(error?.localizedDescription ?? "unknown error")"
        }
    }
}

/// Stitches planned clips into one video, cropped to fill the chosen format.
struct CompilationExporter {
    let library: PhotoLibraryService

    func export(_ clips: [(asset: PHAsset, clip: PlannedClip)], format: ContentFormat) async throws -> URL {
        let renderSize = format.renderSize
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw CompilationError.exportFailed(nil) }

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        var cursor = CMTime.zero

        for (asset, clip) in clips {
            try Task.checkCancellation()
            guard let source = try? await library.avAsset(for: asset, quality: .export),
                  let sourceVideo = try? await source.loadTracks(withMediaType: .video).first,
                  let properties = try? await sourceVideo.load(.naturalSize, .preferredTransform, .timeRange)
            else { continue }
            let (naturalSize, transform, trackRange) = properties

            let start = CMTime(seconds: clip.start, preferredTimescale: 600)
            let available = CMTimeSubtract(CMTimeRangeGetEnd(trackRange), start)
            let duration = CMTimeMinimum(CMTime(seconds: clip.duration, preferredTimescale: 600), available)
            guard duration.seconds > 0.2 else { continue }
            let range = CMTimeRange(start: start, duration: duration)

            do {
                try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)
            } catch {
                continue
            }
            if let sourceAudio = try? await source.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(range, of: sourceAudio, at: cursor)
            }

            layer.setTransform(Self.aspectFill(naturalSize: naturalSize, preferredTransform: transform, into: renderSize), at: cursor)
            cursor = CMTimeAdd(cursor, duration)
        }

        guard cursor.seconds > 0 else { throw CompilationError.nothingToExport }

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: cursor)
        instruction.layerInstructions = [layer]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CompilationError.exportFailed(nil)
        }
        session.videoComposition = videoComposition

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("compilation-\(UUID().uuidString).mov")
        if #available(iOS 18.0, *) {
            do {
                try await session.export(to: url, as: .mov)
            } catch {
                throw CompilationError.exportFailed(error)
            }
        } else {
            session.outputURL = url
            session.outputFileType = .mov
            await session.export()
            guard session.status == .completed else { throw CompilationError.exportFailed(session.error) }
        }
        return url
    }

    /// Rotates the clip upright, then scales and centres it so it fills `renderSize`
    /// (cropping the overflow), e.g. a landscape clip inside a 9:16 reel.
    static func aspectFill(naturalSize: CGSize, preferredTransform: CGAffineTransform, into renderSize: CGSize) -> CGAffineTransform {
        let oriented = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let width = abs(oriented.width), height = abs(oriented.height)
        guard width > 0, height > 0 else { return preferredTransform }
        let scale = max(renderSize.width / width, renderSize.height / height)

        return preferredTransform
            .concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(
                translationX: (renderSize.width - width * scale) / 2,
                y: (renderSize.height - height * scale) / 2
            ))
    }
}
