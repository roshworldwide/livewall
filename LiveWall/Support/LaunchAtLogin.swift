import Foundation
import ServiceManagement

enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return nil }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:        return "Enabled"
        case .notRegistered:  return "Not registered"
        case .requiresApproval: return "Waiting for approval in System Settings › General › Login Items"
        case .notFound:       return "Not found"
        @unknown default:     return "Unknown"
        }
    }
}
