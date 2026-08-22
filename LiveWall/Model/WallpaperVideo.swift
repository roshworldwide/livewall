//
//  WallpaperVideo.swift
//  LiveWall
//

import Foundation
import AppKit

struct WallpaperVideo: Identifiable, Codable, Hashable {

    let id: String
    var name: String

    /// Absolute path at import time. Used as a fallback if the bookmark fails.
    var path: String

    /// Lets the file survive being moved or renamed after import.
    var bookmark: Data?

    /// True when the file was copied into ~/Library/Application Support/LiveWall/Videos.
    var isInLibrary: Bool

    var thumbnailFile: String?
    var duration: Double
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSize: Int64
    var dateAdded: Date

    init(id: String = UUID().uuidString,
         name: String,
         path: String,
         bookmark: Data? = nil,
         isInLibrary: Bool = false,
         thumbnailFile: String? = nil,
         duration: Double = 0,
         pixelWidth: Int = 0,
         pixelHeight: Int = 0,
         fileSize: Int64 = 0,
         dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.bookmark = bookmark
        self.isInLibrary = isInLibrary
        self.thumbnailFile = thumbnailFile
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = fileSize
        self.dateAdded = dateAdded
    }

    // MARK: - File access

    /// Resolves the bookmark first so moved/renamed files keep working.
    func resolvedURL() -> URL? {
        if let data = bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var isMissing: Bool { resolvedURL() == nil }

    var thumbnailURL: URL? {
        guard let thumbnailFile else { return nil }
        return LibraryPaths.thumbnailsDirectory.appendingPathComponent(thumbnailFile)
    }

    // MARK: - Display helpers

    var resolutionLabel: String {
        guard pixelWidth > 0, pixelHeight > 0 else { return "—" }
        let tag: String
        switch pixelHeight {
        case 4320...:      tag = "8K"
        case 2160..<4320:  tag = "4K"
        case 1440..<2160:  tag = "1440p"
        case 1080..<1440:  tag = "1080p"
        case 720..<1080:   tag = "720p"
        default:           tag = ""
        }
        let dims = "\(pixelWidth)×\(pixelHeight)"
        return tag.isEmpty ? dims : "\(dims) · \(tag)"
    }

    var is4KOrBetter: Bool { pixelHeight >= 2160 || pixelWidth >= 3840 }

    var durationLabel: String {
        guard duration.isFinite, duration > 0 else { return "—" }
        let total = Int(duration.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    var fileSizeLabel: String {
        guard fileSize > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
