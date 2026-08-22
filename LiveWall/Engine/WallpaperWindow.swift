//
//  WallpaperWindow.swift
//  LiveWall
//
//  A borderless, click-through window pinned just above the static desktop
//  picture and just below the desktop icons — which is exactly where a live
//  wallpaper belongs.
//

import AppKit

final class WallpaperWindow: NSWindow {

    /// One notch below the desktop-icon layer: video covers the still wallpaper
    /// but icons, Finder and every app window stay on top of it.
    static var wallpaperLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
    }

    init(screen: NSScreen) {
        // NSWindow's only designated initializer is the four-argument one —
        // the `screen:` variant is a convenience and can't be called via super.
        // screen.frame is already in global coordinates, so the window lands on
        // the right display anyway; setFrame(_:display:) below pins it exactly.
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)

        isReleasedWhenClosed = false
        level = WallpaperWindow.wallpaperLevel

        // Follow the user across Spaces, never appear in Mission Control /
        // Cmd-Tab, and never get pulled into another app's full-screen space.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        ignoresMouseEvents = true          // clicks fall through to the desktop
        isOpaque = false
        backgroundColor = .black
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        canHide = false                    // don't vanish on Hide Others
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        tabbingMode = .disallowed

        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func matchFrame(to screen: NSScreen) {
        setFrame(screen.frame, display: true)
        contentView?.frame = NSRect(origin: .zero, size: screen.frame.size)
        contentView?.needsLayout = true
    }
}
