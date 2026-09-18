import Foundation
import AVFoundation
import AppKit
import CoreMedia

enum ThumbnailGenerator {

    static func makeThumbnail(for url: URL,
                              id: String,
                              maxSize: CGSize = CGSize(width: 960, height: 540)) async -> String? {
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 1, preferredTimescale: 600)

        var target = CMTime(seconds: 1.0, preferredTimescale: 600)
        if let duration = try? await asset.load(.duration), duration.isNumeric {
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 {
                target = CMTime(seconds: min(max(seconds * 0.1, 0.1), max(seconds - 0.1, 0.1)),
                                preferredTimescale: 600)
            }
        }

        guard let result = try? await generator.image(at: target) else { return nil }
        let cgImage = result.image

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .jpeg,
                                            properties: [.compressionFactor: 0.82]) else { return nil }

        let fileName = "\(id).jpg"
        let dest = LibraryPaths.thumbnailsDirectory.appendingPathComponent(fileName)
        do {
            LibraryPaths.ensureDirectories()
            try data.write(to: dest, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func probe(url: URL) async -> (duration: Double, width: Int, height: Int)? {
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])

        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        var seconds: Double = 0
        if let duration = try? await asset.load(.duration), duration.isNumeric {
            let value = CMTimeGetSeconds(duration)
            if value.isFinite { seconds = value }
        }

        var width = 0
        var height = 0
        if let (naturalSize, transform) = try? await track.load(.naturalSize, .preferredTransform) {
            let corrected = naturalSize.applying(transform)
            width  = Int(abs(corrected.width).rounded())
            height = Int(abs(corrected.height).rounded())
        }

        return (seconds, width, height)
    }
}
