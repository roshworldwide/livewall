//
//  LibraryView.swift
//  LiveWall
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var prefs: Preferences

    @State private var isDropTargeted = false
    @State private var renaming: WallpaperVideo?
    @State private var draftName = ""

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 16)]

    var body: some View {
        ZStack {
            if library.videos.isEmpty {
                EmptyLibraryView(isDropTargeted: isDropTargeted)
            } else {
                grid
            }

            if isDropTargeted {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .background(Color.accentColor.opacity(0.08))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .sheet(item: $renaming) { video in
            RenameSheet(video: video, draft: $draftName) { newName in
                library.rename(video, to: newName)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(library.videos) { video in
                    VideoCard(
                        video: video,
                        isActive: isActive(video),
                        onSetWallpaper: { WallpaperEngine.shared.setWallpaperEverywhere(video) },
                        onRename: {
                            draftName = video.name
                            renaming = video
                        },
                        onReveal: { library.revealInFinder(video) },
                        onRegenerateThumbnail: {
                            Task {
                                await library.regenerateThumbnail(for: video)
                                ThumbnailCache.shared.invalidate(video.id)
                            }
                        },
                        onRemove: {
                            ThumbnailCache.shared.invalidate(video.id)
                            library.remove(video)
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    private func isActive(_ video: WallpaperVideo) -> Bool {
        if prefs.sameOnAllDisplays { return prefs.globalVideoID == video.id }
        return prefs.globalVideoID == video.id || prefs.assignments.values.contains(video.id)
    }

    // MARK: Drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()

        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, VideoFormats.isAcceptable(url) {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            Task { @MainActor in
                await LibraryStore.shared.importVideos(at: urls)
            }
        }
        return true
    }
}

// MARK: - Card

struct VideoCard: View {

    let video: WallpaperVideo
    let isActive: Bool
    let onSetWallpaper: () -> Void
    let onRename: () -> Void
    let onReveal: () -> Void
    let onRegenerateThumbnail: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ThumbnailImage(video: video)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isActive ? Color.accentColor : Color.black.opacity(0.12),
                                          lineWidth: isActive ? 3 : 1)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if video.is4KOrBetter {
                            Text("4K")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.65), in: Capsule())
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                    }
                    .overlay {
                        if isHovering && !video.isMissing {
                            ZStack {
                                Color.black.opacity(0.35)
                                Button(action: onSetWallpaper) {
                                    Label(isActive ? "Playing" : "Set as Wallpaper",
                                          systemImage: isActive ? "checkmark.circle.fill" : "play.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(isActive)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(video.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(video.resolutionLabel)
                    Text("·")
                    Text(video.durationLabel)
                    Text("·")
                    Text(video.fileSizeLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if video.isMissing {
                    Label("File missing", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Set as Wallpaper", action: onSetWallpaper).disabled(video.isMissing)
            Divider()
            Button("Rename…", action: onRename)
            Button("Show in Finder", action: onReveal)
            Button("Regenerate Thumbnail", action: onRegenerateThumbnail)
            Divider()
            Button("Remove from Library", role: .destructive, action: onRemove)
        }
    }
}

// MARK: - Empty state

struct EmptyLibraryView: View {

    let isDropTargeted: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.tertiary)

            Text("Drop a video here")
                .font(.title3.weight(.medium))

            Text("MP4, M4V or MOV — H.264 or HEVC, up to 4K and beyond.\nLiveWall decodes on the GPU, so large files stay cheap.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                VideoImporter.presentOpenPanel()
            } label: {
                Label("Choose Video…", systemImage: "folder")
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Rename sheet

struct RenameSheet: View {

    let video: WallpaperVideo
    @Binding var draft: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Wallpaper")
                .font(.headline)

            TextField("Name", text: $draft)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .onSubmit { save() }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private func save() {
        onSave(draft)
        dismiss()
    }
}
