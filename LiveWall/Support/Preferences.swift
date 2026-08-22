//
//  Preferences.swift
//  LiveWall
//
//  Single source of truth for "what should be playing and how".
//  The engine observes this object and reacts; the UI only ever writes here.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Fit mode

enum FitMode: String, CaseIterable, Codable, Identifiable {
    case fill
    case fit
    case stretch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fill:    return "Fill Screen"
        case .fit:     return "Fit (letterbox)"
        case .stretch: return "Stretch"
        }
    }

    var subtitle: String {
        switch self {
        case .fill:    return "Crops the edges, no bars. Best for most wallpapers."
        case .fit:     return "Shows the whole frame with black bars."
        case .stretch: return "Distorts the frame to exactly fill the screen."
        }
    }

    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill:    return .resizeAspectFill
        case .fit:     return .resizeAspect
        case .stretch: return .resize
        }
    }
}

extension Notification.Name {
    /// Posted whenever any preference changes. The engine listens for this.
    static let liveWallPreferencesChanged = Notification.Name("LiveWallPreferencesChanged")
}

// MARK: - Preferences

final class Preferences: ObservableObject {

    static let shared = Preferences()

    private enum Key {
        static let fitMode           = "fitMode"
        static let isMuted           = "isMuted"
        static let volume            = "volume"
        static let isPlaying         = "isPlaying"
        static let pauseWhenHidden   = "pauseWhenHidden"
        static let copyIntoLibrary   = "copyIntoLibrary"
        static let sameOnAllDisplays = "sameOnAllDisplays"
        static let globalVideoID     = "globalVideoID"
        static let assignments       = "displayAssignments"
    }

    private let defaults = UserDefaults.standard

    // MARK: Stored settings

    @Published var fitMode: FitMode {
        didSet { defaults.set(fitMode.rawValue, forKey: Key.fitMode); broadcast() }
    }

    @Published var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: Key.isMuted); broadcast() }
    }

    /// 0.0 ... 1.0
    @Published var volume: Double {
        didSet {
            volume = min(max(volume, 0), 1)
            defaults.set(volume, forKey: Key.volume)
            broadcast()
        }
    }

    @Published var isPlaying: Bool {
        didSet { defaults.set(isPlaying, forKey: Key.isPlaying); broadcast() }
    }

    /// Pause decoding when the desktop is fully covered by other windows.
    @Published var pauseWhenHidden: Bool {
        didSet { defaults.set(pauseWhenHidden, forKey: Key.pauseWhenHidden); broadcast() }
    }

    /// Copy imported files into the app's library folder instead of referencing them in place.
    @Published var copyIntoLibrary: Bool {
        didSet { defaults.set(copyIntoLibrary, forKey: Key.copyIntoLibrary) }
    }

    @Published var sameOnAllDisplays: Bool {
        didSet { defaults.set(sameOnAllDisplays, forKey: Key.sameOnAllDisplays); broadcast() }
    }

    /// Used when `sameOnAllDisplays` is true.
    @Published var globalVideoID: String? {
        didSet { defaults.set(globalVideoID, forKey: Key.globalVideoID); broadcast() }
    }

    /// displayKey -> video id. Used when `sameOnAllDisplays` is false.
    @Published var assignments: [String: String] {
        didSet { defaults.set(assignments, forKey: Key.assignments); broadcast() }
    }

    // MARK: Init

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            Key.isMuted: true,
            Key.volume: 0.5,
            Key.isPlaying: true,
            Key.pauseWhenHidden: true,
            Key.copyIntoLibrary: false,
            Key.sameOnAllDisplays: true
        ])

        fitMode           = FitMode(rawValue: d.string(forKey: Key.fitMode) ?? "") ?? .fill
        isMuted           = d.bool(forKey: Key.isMuted)
        volume            = d.double(forKey: Key.volume)
        isPlaying         = d.bool(forKey: Key.isPlaying)
        pauseWhenHidden   = d.bool(forKey: Key.pauseWhenHidden)
        copyIntoLibrary   = d.bool(forKey: Key.copyIntoLibrary)
        sameOnAllDisplays = d.bool(forKey: Key.sameOnAllDisplays)
        globalVideoID     = d.string(forKey: Key.globalVideoID)
        assignments       = d.dictionary(forKey: Key.assignments) as? [String: String] ?? [:]
    }

    // MARK: Helpers

    /// The video id that should play on a given display, honouring the
    /// "same everywhere" switch and falling back to the global choice.
    func videoID(forDisplay key: String) -> String? {
        if sameOnAllDisplays { return globalVideoID }
        return assignments[key] ?? globalVideoID
    }

    func setVideoID(_ id: String?, forDisplay key: String) {
        var copy = assignments
        copy[key] = id
        assignments = copy
    }

    /// Set everywhere: updates the global choice and clears per-display overrides.
    func setVideoEverywhere(_ id: String?) {
        globalVideoID = id
        assignments = [:]
    }

    /// Remove a video that no longer exists from every assignment slot.
    func forgetVideo(id: String) {
        if globalVideoID == id { globalVideoID = nil }
        assignments = assignments.filter { $0.value != id }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: .liveWallPreferencesChanged, object: nil)
    }
}
