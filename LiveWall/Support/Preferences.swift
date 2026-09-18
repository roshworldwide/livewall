import Foundation
import AVFoundation
import Combine

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
    static let liveWallPreferencesChanged = Notification.Name("LiveWallPreferencesChanged")
}

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

    @Published var fitMode: FitMode {
        didSet { defaults.set(fitMode.rawValue, forKey: Key.fitMode); broadcast() }
    }

    @Published var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: Key.isMuted); broadcast() }
    }

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

    @Published var pauseWhenHidden: Bool {
        didSet { defaults.set(pauseWhenHidden, forKey: Key.pauseWhenHidden); broadcast() }
    }

    @Published var copyIntoLibrary: Bool {
        didSet { defaults.set(copyIntoLibrary, forKey: Key.copyIntoLibrary) }
    }

    @Published var sameOnAllDisplays: Bool {
        didSet { defaults.set(sameOnAllDisplays, forKey: Key.sameOnAllDisplays); broadcast() }
    }

    @Published var globalVideoID: String? {
        didSet { defaults.set(globalVideoID, forKey: Key.globalVideoID); broadcast() }
    }

    @Published var assignments: [String: String] {
        didSet { defaults.set(assignments, forKey: Key.assignments); broadcast() }
    }

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

    func videoID(forDisplay key: String) -> String? {
        if sameOnAllDisplays { return globalVideoID }
        return assignments[key] ?? globalVideoID
    }

    func setVideoID(_ id: String?, forDisplay key: String) {
        var copy = assignments
        copy[key] = id
        assignments = copy
    }

    func setVideoEverywhere(_ id: String?) {
        globalVideoID = id
        assignments = [:]
    }

    func forgetVideo(id: String) {
        if globalVideoID == id { globalVideoID = nil }
        assignments = assignments.filter { $0.value != id }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: .liveWallPreferencesChanged, object: nil)
    }
}
