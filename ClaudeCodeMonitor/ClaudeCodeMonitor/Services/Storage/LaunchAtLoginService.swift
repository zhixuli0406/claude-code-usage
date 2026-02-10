import Foundation
import ServiceManagement

/// Service for managing "Launch at Login" using SMAppService (macOS 13+)
@available(macOS 14.0, *)
final class LaunchAtLoginService {

    /// Whether the app is currently registered to launch at login
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register the app to launch at login
    func enable() throws {
        try SMAppService.mainApp.register()
    }

    /// Unregister the app from launching at login
    func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    /// Toggle launch at login on/off
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }
}
