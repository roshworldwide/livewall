import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case library
    case displays
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library:  return "Library"
        case .displays: return "Displays"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .library:  return "photo.stack"
        case .displays: return "display.2"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var prefs: Preferences
    @State private var tab: MainTab = .library

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            StatusBar()
        }
        .frame(minWidth: 760, minHeight: 520)
        .alert("Something went wrong",
               isPresented: Binding(
                get: { library.lastError != nil },
                set: { if !$0 { library.lastError = nil } }
               ),
               actions: { Button("OK", role: .cancel) { library.lastError = nil } },
               message: { Text(library.lastError ?? "") })
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker("", selection: $tab) {
                ForEach(MainTab.allCases) { item in
                    Label(item.title, systemImage: item.symbol).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 340)

            Spacer()

            Button {
                VideoImporter.presentOpenPanel()
            } label: {
                Label("Add Video", systemImage: "plus")
            }
            .help("Add one or more videos to your library")
            .disabled(library.importStatus != nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .library:  LibraryView()
        case .displays: DisplaysView()
        case .settings: SettingsView()
        }
    }
}

struct StatusBar: View {

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var prefs: Preferences

    var body: some View {
        HStack(spacing: 10) {
            if let status = library.importStatus {
                ProgressView()
                    .controlSize(.small)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Image(systemName: prefs.isPlaying ? "play.fill" : "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(WallpaperEngine.shared.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                prefs.isPlaying.toggle()
            } label: {
                Label(prefs.isPlaying ? "Pause" : "Play",
                      systemImage: prefs.isPlaying ? "pause.fill" : "play.fill")
            }
            .controlSize(.small)

            Button {
                prefs.isMuted.toggle()
            } label: {
                Image(systemName: prefs.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .controlSize(.small)
            .help(prefs.isMuted ? "Unmute wallpaper audio" : "Mute wallpaper audio")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
