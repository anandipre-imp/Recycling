import Foundation

/// A cut from one source video: play `duration` seconds starting at `start`.
struct PlannedClip: Hashable {
    let videoID: String
    let start: Double
    let duration: Double
}

enum ClipPlanner {
    /// Picks clips for a short video of roughly `targetDuration` seconds.
    ///
    /// `videos` should be ordered best-first: if they don't all fit, the first ones win.
    /// The chosen clips are returned in chronological order, each centred on the
    /// video's highlight moment.
    static func plan(
        _ videos: [VideoAnalysis],
        targetDuration: Double = 30,
        minClipLength: Double = 1.5,
        maxClipLength: Double = 3
    ) -> [PlannedClip] {
        let usable = videos.filter { $0.duration > 0.5 }
        guard !usable.isEmpty else { return [] }

        let maxCount = max(1, Int(targetDuration / minClipLength))
        let chosen = usable.prefix(maxCount)
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        let perClip = min(maxClipLength, max(minClipLength, targetDuration / Double(chosen.count)))

        return chosen.map { video in
            let length = min(perClip, video.duration)
            let start = min(max(0, video.highlightTime - length / 2), video.duration - length)
            return PlannedClip(videoID: video.id, start: start, duration: length)
        }
    }
}
