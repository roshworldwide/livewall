import SwiftUI
import AppKit

struct SettingsView: View {

    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var library: LibraryStore

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?
    @State private var diskUsage: Int64 = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                section("Playback") {
                    VStack(alignment: .leading, spacing: 14) {

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Scaling").font(.subheadline.weight(.medium))
                            Picker("", selection: $prefs.fitMode) {
                                ForEach(FitMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(maxWidth: 420)
                            Text(prefs.fitMode.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Toggle(isOn: $prefs.isPlaying) {
                            Text("Play wallpaper")
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: Binding(get: { !prefs.isMuted },
                                             set: { prefs.isMuted = !$0 })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Play audio")
                                Text("Audio comes from the main display only.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        HStack(spacing: 10) {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(.secondary)
                            Slider(value: $prefs.volume, in: 0...1)
                                .frame(maxWidth: 300)
                                .disabled(prefs.isMuted)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(.secondary)
                            Text("\(Int(prefs.volume * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .leading)
                        }
                        .opacity(prefs.isMuted ? 0.5 : 1)
                    }
                }

                section("Performance") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $prefs.pauseWhenHidden) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pause when the desktop is covered")
                                Text("Stops decoding while windows fully hide the wallpaper. Recommended on laptops.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        LabeledContent("Status") {
                            Text(WallpaperEngine.shared.statusSummary)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                section("Library") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $prefs.copyIntoLibrary) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy imported videos into the library")
                                Text("Off by default — LiveWall references files where they already live, so a 4 GB video isn't duplicated.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        LabeledContent("Videos") {
                            Text("\(library.videos.count)")
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Space used by copies") {
                            Text(ByteCountFormatter.string(fromByteCount: diskUsage, countStyle: .file))
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            LibraryPaths.revealInFinder()
                        } label: {
                            Label("Show Library Folder", systemImage: "folder")
                        }
                    }
                }

                section("Startup") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { launchAtLogin },
                            set: { newValue in
                                if let reason = LaunchAtLogin.set(newValue) {
                                    loginError = reason
                                } else {
                                    loginError = nil
                                }
                                launchAtLogin = LaunchAtLogin.isEnabled
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch LiveWall at login")
                                Text(LaunchAtLogin.statusDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        if let loginError {
                            Label(loginError, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Move LiveWall.app into /Applications and try again — macOS won't register login items from a temporary build folder.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                section("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Version") {
                            Text(Self.versionString).foregroundStyle(.secondary)
                        }
                        Text("LiveWall renders video on a window pinned between your desktop picture and your desktop icons. Decoding runs through AVFoundation, so H.264 and HEVC — including 4K — are handled by the GPU's media engine.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            diskUsage = LibraryPaths.diskUsage()
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
