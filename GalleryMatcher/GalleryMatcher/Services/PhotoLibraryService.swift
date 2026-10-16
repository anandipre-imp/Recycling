import AVFoundation
import Photos
import UIKit

enum PhotoLibraryError: LocalizedError {
    case assetUnavailable

    var errorDescription: String? {
        "This video couldn't be loaded. If it's stored in iCloud, check your internet connection."
    }
}

/// Thin async wrapper around PhotoKit. Stateless, so safe to share across tasks.
final class PhotoLibraryService: @unchecked Sendable {
    enum Quality {
        /// Smaller file, faster to fetch from iCloud — plenty for AI analysis.
        case analysis
        /// Full quality for the exported video.
        case export
    }

    private let imageManager = PHCachingImageManager()

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// All videos the app can see, newest first.
    func fetchVideos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .video, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func avAsset(for asset: PHAsset, quality: Quality) async throws -> AVAsset {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = quality == .analysis ? .mediumQualityFormat : .highQualityFormat
        options.version = .current

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: (info?[PHImageErrorKey] as? Error) ?? PhotoLibraryError.assetUnavailable)
                }
            }
        }
    }

    func thumbnail(for asset: PHAsset, size: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        // .highQualityFormat guarantees the handler is called exactly once.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func saveVideo(at url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
