//
//  MenuBarController.swift
//  LiveWall
//
//  The status-bar item is the primary way to drive the app day to day.
//  The menu is rebuilt lazily each time it opens so it always reflects reality.
//

import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    var onOpenLibrary: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var volumeView: VolumeSliderView?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "play.rectangle.fill",
                                   accessibilityDescription: "LiveWall")
            button.image?.isTemplate = true
            button.toolTip = "LiveWall"
        }

        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    // MARK: - Menu construction

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let prefs = Preferences.shared
        let engine = WallpaperEngine.shared
        let library = LibraryStore.shared

        // --- Header: what's playing -------------------------------------
        let current = engine.currentVideo
        let header = NSMenuItem(title: current?.name ?? "No wallpaper set",
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        if let current {
            header.attributedTitle = attributed(title: current.name,
                                                subtitle: "\(current.resolutionLabel) · \(engine.statusSummary)")
        } else {
            header.attributedTitle = attributed(title: "No wallpaper set",
                                                subtitle: "Add a video to get started")
        }
        menu.addItem(header)
        menu.addItem(.separator())

        // --- Transport ---------------------------------------------------
        let playPause = NSMenuItem(title: prefs.isPlaying ? "Pause" : "Play",
                                   action: #selector(togglePlayPause),
                                   keyEquivalent: "")
        playPause.target = self
        playPause.image = NSImage(systemSymbolName: prefs.isPlaying ? "pause.fill" : "play.fill",
                                  accessibilityDescription: nil)
        menu.addItem(playPause)

        let mute = NSMenuItem(title: prefs.isMuted ? "Unmute" : "Mute",
                              action: #selector(toggleMute),
                              keyEquivalent: "")
        mute.target = self
        mute.image = NSImage(systemSymbolName: prefs.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                             accessibilityDescription: nil)
        menu.addItem(mute)

        // Inline volume slider
        let volumeItem = NSMenuItem()
        let slider = VolumeSliderView(value: prefs.volume) { newValue in
            Preferences.shared.volume = newValue
            if newValue > 0 { Preferences.shared.isMuted = false }
        }
        slider.isEnabled = !prefs.isMuted
        volumeItem.view = slider
        volumeView = slider
        menu.addItem(volumeItem)

        menu.addItem(.separator())

        // --- Wallpaper picker --------------------------------------------
        let wallpaperItem = NSMenuItem(title: "Wallpaper", action: nil, keyEquivalent: "")
        wallpaperItem.image = NSImage(systemSymbolName: "photo.stack", accessibilityDescription: nil)
        let wallpaperMenu = NSMenu()

        if library.videos.isEmpty {
            let empty = NSMenuItem(title: "Library is empty", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            wallpaperMenu.addItem(empty)
        } else {
            for video in library.videos.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
                let item = NSMenuItem(title: video.name,
                                      action: #selector(selectWallpaper(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = video.id
                item.state = (current?.id == video.id) ? .on : .off
                if video.isMissing {
                    item.attributedTitle = attributed(title: video.name, subtitle: "File missing")
                }
                wallpaperMenu.addItem(item)
            }
            wallpaperMenu.addItem(.separator())
            let none = NSMenuItem(title: "None (static desktop)",
                                  action: #selector(clearWallpaper),
                                  keyEquivalent: "")
            none.target = self
            wallpaperMenu.addItem(none)
        }
        wallpaperItem.submenu = wallpaperMenu
        menu.addItem(wallpaperItem)

        // --- Per-display submenu (only when there is more than one) --------
        if NSScreen.screens.count > 1 {
            let displaysItem = NSMenuItem(title: "Displays", action: nil, keyEquivalent: "")
            displaysItem.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: nil)
            let displaysMenu = NSMenu()

            let mirror = NSMenuItem(title: "Same Wallpaper Everywhere",
                                    action: #selector(toggleSameEverywhere),
                                    keyEquivalent: "")
            mirror.target = self
            mirror.state = prefs.sameOnAllDisplays ? .on : .off
            displaysMenu.addItem(mirror)
            displaysMenu.addItem(.separator())

            for screen in NSScreen.screens {
                let key = WallpaperEngine.key(for: screen)
                let screenItem = NSMenuItem(title: WallpaperEngine.displayName(for: screen),
                                            action: nil, keyEquivalent: "")
                let screenMenu = NSMenu()
                let assignedID = prefs.videoID(forDisplay: key)

                for video in library.videos {
                    let item = NSMenuItem(title: video.name,
                                          action: #selector(assignToDisplay(_:)),
                                          keyEquivalent: "")
                    item.target = self
                    item.representedObject = ["display": key, "video": video.id]
                    item.state = (assignedID == video.id) ? .on : .off
                    item.isEnabled = !prefs.sameOnAllDisplays
                    screenMenu.addItem(item)
                }
                screenItem.submenu = screenMenu
                screenItem.isEnabled = !prefs.sameOnAllDisplays
                displaysMenu.addItem(screenItem)
            }
            displaysItem.submenu = displaysMenu
            menu.addItem(displaysItem)
        }

        // --- Fit mode -----------------------------------------------------
        let fitItem = NSMenuItem(title: "Scaling", action: nil, keyEquivalent: "")
        fitItem.image = NSImage(systemSymbolName: "aspectratio", accessibilityDescription: nil)
        let fitMenu = NSMenu()
        for mode in FitMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectFit(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (prefs.fitMode == mode) ? .on : .off
            fitMenu.addItem(item)
        }
        fitItem.submenu = fitMenu
        menu.addItem(fitItem)

        menu.addItem(.separator())

        // --- Library actions ----------------------------------------------
        let add = NSMenuItem(title: "Add Video…", action: #selector(addVideo), keyEquivalent: "")
        add.target = self
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        menu.addItem(add)

        let open = NSMenuItem(title: "Open LiveWall…", action: #selector(openLibrary), keyEquivalent: "")
        open.target = self
        open.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        menu.addItem(open)

        menu.addItem(.separator())

        // --- Behaviour toggles ---------------------------------------------
        let pauseHidden = NSMenuItem(title: "Pause When Covered",
                                     action: #selector(togglePauseWhenHidden),
                                     keyEquivalent: "")
        pauseHidden.target = self
        pauseHidden.state = prefs.pauseWhenHidden ? .on : .off
        pauseHidden.toolTip = "Stops decoding while every window covers the desktop. Saves battery."
        menu.addItem(pauseHidden)

        let login = NSMenuItem(title: "Launch at Login",
                               action: #selector(toggleLaunchAtLogin),
                               keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit LiveWall", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func togglePlayPause() { Preferences.shared.isPlaying.toggle() }

    @objc private func toggleMute() { Preferences.shared.isMuted.toggle() }

    @objc private func togglePauseWhenHidden() { Preferences.shared.pauseWhenHidden.toggle() }

    @objc private func toggleSameEverywhere() { Preferences.shared.sameOnAllDisplays.toggle() }

    @objc private func toggleLaunchAtLogin() {
        let wanted = !LaunchAtLogin.isEnabled
        if let reason = LaunchAtLogin.set(wanted) {
            presentAlert(title: "Couldn't change Launch at Login",
                         message: "\(reason)\n\nTip: move LiveWall.app into your Applications folder and try again.")
        }
    }

    @objc private func selectWallpaper(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let video = LibraryStore.shared.video(withID: id) else { return }
        WallpaperEngine.shared.setWallpaperEverywhere(video)
    }

    @objc private func clearWallpaper() {
        WallpaperEngine.shared.setWallpaperEverywhere(nil)
    }

    @objc private func assignToDisplay(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let displayKey = info["display"],
              let videoID = info["video"],
              let video = LibraryStore.shared.video(withID: videoID) else { return }
        WallpaperEngine.shared.setWallpaper(video, onDisplay: displayKey)
    }

    @objc private func selectFit(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = FitMode(rawValue: raw) else { return }
        Preferences.shared.fitMode = mode
    }

    @objc private func addVideo() {
        VideoImporter.presentOpenPanel()
    }

    @objc private func openLibrary() { onOpenLibrary?() }

    @objc private func quit() { onQuit?() }

    // MARK: - Helpers

    private func attributed(title: String, subtitle: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: title,
            attributes: [.font: NSFont.menuFont(ofSize: 0)]
        )
        result.append(NSAttributedString(
            string: "\n" + subtitle,
            attributes: [
                .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        return result
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Volume slider menu item

final class VolumeSliderView: NSView {

    private let slider = NSSlider()
    private let icon = NSImageView()
    private let onChange: (Double) -> Void

    var isEnabled: Bool = true {
        didSet {
            slider.isEnabled = isEnabled
            icon.alphaValue = isEnabled ? 1.0 : 0.4
        }
    }

    init(value: Double, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 28))

        icon.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Volume")
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = value
        slider.target = self
        slider.action = #selector(sliderMoved)
        slider.isContinuous = true
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),

            slider.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func sliderMoved() {
        onChange(slider.doubleValue)
    }
}
