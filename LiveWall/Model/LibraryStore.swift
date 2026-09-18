import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {

    static let shared = LibraryStore()

    @Published private(set) var videos: [WallpaperVideo] = []

    @Published var importStatus: String?
    @Published var lastError: String?

    private init() {}

    func load() {
        LibraryPaths.ensureDirectories()
        guard let data = try? Data(contentsOf: LibraryPaths.libraryFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([WallpaperVideo].self, from: data) {
            videos = decoded
        }
    }

    func save() {
        LibraryPaths.ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(videos) else { return }
        try? data.write(to: LibraryPaths.libraryFile, options: .atomic)
    }

    func video(withID id: String?) -> WallpaperVideo? {
        guard let id else { return nil }
        return videos.first { $0.id == id }
    }

    func importVideos(at urls: [URL]) async {
        let candidates = urls.filter { VideoFormats.isAcceptable($0) }
        let rejected = urls.count - candidates.count

        guard !candidates.isEmpty else {
            if rejected > 0 {
                lastError = "Those files aren't playable video containers. Use .mp4, .m4v or .mov (H.264 or HEVC)."
            }
            return
        }

        var added: [WallpaperVideo] = []

        for (index, source) in candidates.enumerated() {
            importStatus = "Importing \(index + 1) of \(candidates.count) — \(source.lastPathComponent)"

            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }

            guard let meta = await ThumbnailGenerator.probe(url: source) else {
                lastError = "\(source.lastPathComponent) has no video track LiveWall can decode."
                continue
            }

            let id = UUID().uuidString
            var finalURL = source
            var copied = false

            if Preferences.shared.copyIntoLibrary {
                let dest = LibraryPaths.videosDirectory
                    .appendingPathComponent("\(id)-\(source.lastPathComponent)")
                do {
                    try FileManager.default.copyItem(at: source, to: dest)
                    finalURL = dest
                    copied = true
                } catch {
                    lastError = "Couldn't copy \(source.lastPathComponent) into the library — referencing it in place instead."
                }
            }

            let bookmark = try? finalURL.bookmarkData(options: [],
                                                      includingResourceValuesForKeys: nil,
                                                      relativeTo: nil)
            let size = (try? finalURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let thumbnail = await ThumbnailGenerator.makeThumbnail(for: finalURL, id: id)

            let video = WallpaperVideo(
                id: id,
                name: source.deletingPathExtension().lastPathComponent,
                path: finalURL.path,
                bookmark: bookmark,
                isInLibrary: copied,
                thumbnailFile: thumbnail,
                duration: meta.duration,
                pixelWidth: meta.width,
                pixelHeight: meta.height,
                fileSize: Int64(size),
                dateAdded: Date()
            )
            added.append(video)
        }

        importStatus = nil

        guard !added.isEmpty else { return }
        videos.append(contentsOf: added)
        save()

        if Preferences.shared.globalVideoID == nil, let first = added.first {
            Preferences.shared.setVideoEverywhere(first.id)
        }
    }

    func rename(_ video: WallpaperVideo, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = videos.firstIndex(where: { $0.id == video.id }) else { return }
        videos[index].name = trimmed
        save()
    }

    func remove(_ video: WallpaperVideo) {
        videos.removeAll { $0.id == video.id }

        if video.isInLibrary, let url = video.resolvedURL() {
            try? FileManager.default.removeItem(at: url)
        }
        if let thumb = video.thumbnailURL {
            try? FileManager.default.removeItem(at: thumb)
        }

        Preferences.shared.forgetVideo(id: video.id)
        save()
    }

    func regenerateThumbnail(for video: WallpaperVideo) async {
        guard let url = video.resolvedURL(),
              let index = videos.firstIndex(where: { $0.id == video.id }) else { return }
        if let file = await ThumbnailGenerator.makeThumbnail(for: url, id: video.id) {
            videos[index].thumbnailFile = file
            save()
        }
    }

    func revealInFinder(_ video: WallpaperVideo) {
        guard let url = video.resolvedURL() else {
            lastError = "\(video.name) can't be found on disk any more."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

enum VideoFormats {

    static let extensions: Set<String> = ["mp4", "m4v", "mov", "qt"]

    static func isAcceptable(_ url: URL) -> Bool {
        if extensions.contains(url.pathExtension.lowercased()) { return true }
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .movie) || type.conforms(to: .video) {
            return true
        }
        return false
    }
}

enum VideoImporter {

    static func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Add Wallpaper Videos"
        panel.prompt = "Add"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]

        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in
                await LibraryStore.shared.importVideos(at: urls)
            }
        }
    }
}
