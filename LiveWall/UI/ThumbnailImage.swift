//
//  ThumbnailImage.swift
//  LiveWall
//
//  Disk-backed poster frames with a tiny in-memory cache so scrolling the
//  library grid doesn't re-decode JPEGs on every pass.
//

import SwiftUI
import AppKit

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [String: NSImage] = [:]

    func image(for video: WallpaperVideo) -> NSImage? {
        if let cached = cache[video.id] { return cached }
        guard let url = video.thumbnailURL,
              let image = NSImage(contentsOf: url) else { return nil }
        cache[video.id] = image
        return image
    }

    func invalidate(_ id: String) { cache.removeValue(forKey: id) }
    func removeAll() { cache.removeAll() }
}

struct ThumbnailImage: View {

    let video: WallpaperVideo
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if let image = ThumbnailCache.shared.image(for: video) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(nsColor: .controlBackgroundColor),
                                        Color(nsColor: .underPageBackgroundColor)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                Image(systemName: "film")
                    .font(.system(size: 26))
                    .foregroundStyle(.tertiary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
