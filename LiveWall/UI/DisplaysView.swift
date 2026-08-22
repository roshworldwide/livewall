//
//  DisplaysView.swift
//  LiveWall
//
//  Per-display wallpaper assignment. Rebuilds itself whenever monitors are
//  plugged, unplugged or rearranged.
//

import SwiftUI
import AppKit

// MARK: - Screen list that stays current

@MainActor
final class ScreenObserver: ObservableObject {

    struct Entry: Identifiable, Hashable {
        let id: String        // engine display key
        let name: String
        let width: Int
        let height: Int
        let scale: CGFloat
        let isMain: Bool

        var resolutionLabel: String {
            let backing = scale > 1 ? " @\(Int(scale))x" : ""
            return "\(width)×\(height)\(backing)"
        }
    }

    @Published private(set) var screens: [Entry] = []

    init() {
        refresh()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let main = NSScreen.main
        screens = NSScreen.screens.map { screen in
            Entry(id: WallpaperEngine.key(for: screen),
                  name: WallpaperEngine.displayName(for: screen),
                  width: Int(screen.frame.width),
                  height: Int(screen.frame.height),
                  scale: screen.backingScaleFactor,
                  isMain: screen == main)
        }
    }
}

// MARK: - View

struct DisplaysView: View {

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var prefs: Preferences
    @StateObject private var observer = ScreenObserver()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Toggle(isOn: $prefs.sameOnAllDisplays) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use the same wallpaper on every display")
                        Text("Turn this off to give each monitor its own video.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                if library.videos.isEmpty {
                    ContentPlaceholder(
                        symbol: "photo.badge.plus",
                        title: "No videos yet",
                        message: "Add a video in the Library tab, then assign it to a display here."
                    )
                } else {
                    ForEach(observer.screens) { screen in
                        DisplayRow(screen: screen)
                            .environmentObject(library)
                            .environmentObject(prefs)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - One display

struct DisplayRow: View {

    let screen: ScreenObserver.Entry

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var prefs: Preferences

    private var assignedID: String? { prefs.videoID(forDisplay: screen.id) }
    private var assigned: WallpaperVideo? { library.video(withID: assignedID) }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // Preview
            Group {
                if let assigned {
                    ThumbnailImage(video: assigned, cornerRadius: 6)
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay {
                            Image(systemName: "display")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: 176, height: 99)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(screen.name)
                        .font(.headline)
                    if screen.isMain {
                        Text("MAIN")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text(screen.resolutionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Wallpaper", selection: Binding(
                    get: { assignedID ?? "" },
                    set: { newValue in
                        let id = newValue.isEmpty ? nil : newValue
                        if prefs.sameOnAllDisplays {
                            prefs.setVideoEverywhere(id)
                        } else {
                            prefs.setVideoID(id, forDisplay: screen.id)
                        }
                    }
                )) {
                    Text("None").tag("")
                    ForEach(library.videos) { video in
                        Text(video.name).tag(video.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320)

                if prefs.sameOnAllDisplays {
                    Text("Mirrored — changing this changes every display.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Shared placeholder

struct ContentPlaceholder: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
