//
//  main.swift
//  LiveWall
//
//  Entry point. We drive NSApplication manually (instead of @main / SwiftUI App)
//  so the process starts as a menu-bar agent with no Dock icon, and only
//  becomes a "regular" app while the library window is open.
//

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
