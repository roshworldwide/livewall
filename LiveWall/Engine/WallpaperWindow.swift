import AppKit

final class WallpaperWindow: NSWindow {

    static var wallpaperLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
    }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)

        isReleasedWhenClosed = false
        level = WallpaperWindow.wallpaperLevel

        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .black
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        canHide = false
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
