//
//  LibraryPaths.swift
//  LiveWall
//
//  All on-disk locations used by the app live under
//  ~/Library/Application Support/LiveWall/
//

import Foundation
import AppKit

enum LibraryPaths {

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("LiveWall", isDirectory: true)
    }

    /// Where imported copies live (only used when "Copy into library" is on).
    static var videosDirectory: URL {
        root.appendingPathComponent("Videos", isDirectory: true)
    }

    /// Cached poster frames, one JPEG per library entry.
    static var thumbnailsDirectory: URL {
        root.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    static var libraryFile: URL {
        root.appendingPathComponent("library.json")
    }

    static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [root, videosDirectory, thumbnailsDirectory] where !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func revealInFinder() {
        ensureDirectories()
        NSWorkspace.shared.activateFileViewerSelecting([root])
    }

    /// Total bytes occupied by copied videos + thumbnails.
    static func diskUsage() -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        for dir in [videosDirectory, thumbnailsDirectory] {
            guard let items = try? fm.contentsOfDirectory(at: dir,
                                                          includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for item in items {
                let size = (try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                total += Int64(size)
            }
        }
        return total
    }
}
