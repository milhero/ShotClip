import ServiceManagement

/// Thin wrapper around `SMAppService` for the "Launch at Login" toggle.
/// Registering only works when the app runs as a proper bundle from
/// /Applications (i.e. installed via `make install`).
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
