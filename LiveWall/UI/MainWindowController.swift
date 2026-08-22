//
//  MainWindowController.swift
//  LiveWall
//

import AppKit
import SwiftUI

final class MainWindowController: NSWindowController, NSWindowDelegate {

    var onClose: (() -> Void)?

    init() {
        let root = MainWindowView()
            .environmentObject(LibraryStore.shared)
            .environmentObject(Preferences.shared)

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "LiveWall"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 940, height: 640))
        window.minSize = NSSize(width: 760, height: 520)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("LiveWallMainWindow")

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
