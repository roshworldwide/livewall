//
//  WallpaperEngine.swift
//  LiveWall
//
//  Owns one desktop-level window + one AVQueuePlayer per physical display.
//  AVPlayerLooper gives gapless looping; AVFoundation gives hardware-accelerated
//  H.264/HEVC decode, which is what makes 4K playback cheap on Apple silicon.
//

import AppKit
import AVFoundation
import Combine

// MARK: - Per-display output

final class DisplayOutput {
    let key: String
    let window: WallpaperWindow
    let content: WallpaperContentView
    let player: AVQueuePlayer
    var looper: AVPlayerLooper?
    var videoID: String?
    var isCovered = false

    init(key: String, window: WallpaperWindow, content: WallpaperContentView, player: AVQueuePlayer) {
        self.key = key
        self.window = window
        self.content = content
        self.player = player
    }
}

// MARK: - Engine

@MainActor
final class WallpaperEngine: NSObject, ObservableObject {

    static let shared = WallpaperEngine()

    /// key -> output, one per connected display.
    private(set) var outputs: [String: DisplayOutput] = [:]

    /// Set while the system is asleep or the screen is locked.
    private var systemSuspended = false

    private var started = false

    private override init() { super.init() }

    // MARK: - Display identity

    /// Stable-enough identity for a screen: the human name plus the display id.
    /// If a monitor is swapped and the key no longer matches, that display simply
    /// falls back to the global wallpaper — never to a blank screen.
    static func key(for screen: NSScreen) -> String {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let displayID = number?.uint32Value ?? 0
        return "\(screen.localizedName)|\(displayID)"
    }

    static func displayName(for screen: NSScreen) -> String { screen.localizedName }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true

        rebuildOutputs()
        registerObservers()
        syncFromPreferences()
    }

    func stop() {
        for output in outputs.values {
            output.looper?.disableLooping()
            output.player.pause()
            output.player.removeAllItems()
            output.window.orderOut(nil)
        }
        outputs.removeAll()
    }

    private func registerObservers() {
        let center = NotificationCenter.default

        center.addObserver(self,
                           selector: #selector(preferencesChanged),
                           name: .liveWallPreferencesChanged,
                           object: nil)

        center.addObserver(self,
                           selector: #selector(screenParametersChanged),
                           name: NSApplication.didChangeScreenParametersNotification,
                           object: nil)

        center.addObserver(self,
                           selector: #selector(occlusionChanged(_:)),
                           name: NSWindow.didChangeOcclusionStateNotification,
                           object: nil)

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillSleep),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake),
                              name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemWillSleep),
                              name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake),
                              name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    // MARK: - Screen management

    @objc private func screenParametersChanged() {
        rebuildOutputs()
        syncFromPreferences()
    }

    private func rebuildOutputs() {
        let screens = NSScreen.screens
        var liveKeys = Set<String>()

        for screen in screens {
            let key = Self.key(for: screen)
            liveKeys.insert(key)

            if let existing = outputs[key] {
                existing.window.matchFrame(to: screen)
                existing.window.orderFrontRegardless()
            } else {
                outputs[key] = makeOutput(for: screen, key: key)
            }
        }

        // Tear down anything for a display that went away.
        for (key, output) in outputs where !liveKeys.contains(key) {
            output.looper?.disableLooping()
            output.player.pause()
            output.player.removeAllItems()
            output.window.orderOut(nil)
            outputs.removeValue(forKey: key)
        }
    }

    private func makeOutput(for screen: NSScreen, key: String) -> DisplayOutput {
        let window = WallpaperWindow(screen: screen)
        let content = WallpaperContentView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.contentView = content

        let player = AVQueuePlayer()
        player.actionAtItemEnd = .advance
        player.isMuted = true
        // Local files: don't stall waiting for a buffer we already have.
        player.automaticallyWaitsToMinimizeStalling = false
        content.playerLayer.player = player

        window.orderFrontRegardless()

        return DisplayOutput(key: key, window: window, content: content, player: player)
    }

    // MARK: - Preference sync

    @objc private func preferencesChanged() {
        syncFromPreferences()
    }

    /// Reconciles every output with whatever Preferences currently says.
    func syncFromPreferences() {
        let prefs = Preferences.shared
        let library = LibraryStore.shared

        // Audio only ever comes from the main display; N unmuted players is noise.
        let mainKey = NSScreen.main.map { Self.key(for: $0) }

        for (key, output) in outputs {
            let wantedID = prefs.videoID(forDisplay: key)
            let wanted = library.video(withID: wantedID)

            if output.videoID != wanted?.id {
                load(wanted, into: output)
            }

            output.content.apply(fitMode: prefs.fitMode)

            let isAudioOutput = (key == mainKey) || (mainKey == nil)
            output.player.isMuted = prefs.isMuted || !isAudioOutput
            output.player.volume = Float(prefs.volume)

            updatePlayback(for: output)
        }
    }

    private func load(_ video: WallpaperVideo?, into output: DisplayOutput) {
        output.looper?.disableLooping()
        output.looper = nil
        output.player.pause()
        output.player.removeAllItems()

        guard let video, let url = video.resolvedURL() else {
            output.videoID = nil
            return
        }

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 4

        // AVPlayerLooper enqueues copies of the template item so the loop point
        // has no gap or black flash — much better than seeking on didPlayToEnd.
        output.looper = AVPlayerLooper(player: output.player, templateItem: item)
        output.videoID = video.id
        output.content.crossfade()

        updatePlayback(for: output)
    }

    // MARK: - Playback gating

    /// A display plays only when: the user wants playback, the system is awake,
    /// and (if the setting is on) the desktop is not completely covered.
    private func updatePlayback(for output: DisplayOutput) {
        let prefs = Preferences.shared
        let hiddenBlocks = prefs.pauseWhenHidden && output.isCovered
        let shouldPlay = prefs.isPlaying && !systemSuspended && !hiddenBlocks && output.videoID != nil

        if shouldPlay {
            if output.player.rate == 0 { output.player.play() }
        } else {
            if output.player.rate != 0 { output.player.pause() }
        }
    }

    @objc private func occlusionChanged(_ note: Notification) {
        guard let window = note.object as? WallpaperWindow else { return }
        guard let output = outputs.values.first(where: { $0.window === window }) else { return }
        output.isCovered = !window.occlusionState.contains(.visible)
        updatePlayback(for: output)
    }

    @objc private func systemWillSleep() {
        systemSuspended = true
        for output in outputs.values { updatePlayback(for: output) }
    }

    @objc private func systemDidWake() {
        systemSuspended = false
        // Displays can be re-enumerated on wake; rebuild before resuming.
        rebuildOutputs()
        syncFromPreferences()
    }

    // MARK: - Public controls (used by the menu bar and UI)

    func togglePlayPause() {
        Preferences.shared.isPlaying.toggle()
    }

    func setWallpaperEverywhere(_ video: WallpaperVideo?) {
        Preferences.shared.setVideoEverywhere(video?.id)
    }

    func setWallpaper(_ video: WallpaperVideo?, onDisplay key: String) {
        Preferences.shared.sameOnAllDisplays = false
        Preferences.shared.setVideoID(video?.id, forDisplay: key)
    }

    /// Currently-playing video on the main display, for menu-bar labels.
    var currentVideo: WallpaperVideo? {
        let key = NSScreen.main.map { Self.key(for: $0) }
        let id = key.flatMap { Preferences.shared.videoID(forDisplay: $0) }
            ?? Preferences.shared.globalVideoID
        return LibraryStore.shared.video(withID: id)
    }

    /// Rough health readout shown in Settings.
    var statusSummary: String {
        let count = outputs.count
        let playing = outputs.values.filter { $0.player.rate != 0 }.count
        let displayWord = count == 1 ? "display" : "displays"
        if !Preferences.shared.isPlaying { return "Paused · \(count) \(displayWord)" }
        if playing == 0 { return "Idle · \(count) \(displayWord)" }
        return "Playing on \(playing) of \(count) \(displayWord)"
    }
}
