import ServiceManagement
import AppKit

/// Thin wrapper around `SMAppService` for the "Launch at Login" toggle.
/// Registering only works when the app runs as a proper bundle from
/// /Applications (i.e. installed via `make install`).
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// macOS accepted the registration but the user still has to approve it
    /// under System Settings ▸ General ▸ Login Items. Until then the app does
    /// **not** launch at login — the usual reason "launch at login" seems to
    /// only half work.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Opens the Login Items settings pane so the user can approve a pending
    /// item. Falls back to the General pane on older systems.
    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.users", // legacy
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }
}
