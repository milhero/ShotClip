import Foundation

/// Reads and writes the native macOS screenshot save location — the
/// `com.apple.screencapture` preference domain used by ⌘⇧3 / ⌘⇧4 / ⌘⇧5.
///
/// Because macOS itself saves the file there, the "save to folder" half of
/// the workflow is 100% native and needs no code at capture time.
enum ScreenCaptureDefaults {

    private static let domain = "com.apple.screencapture" as CFString
    private static let key = "location" as CFString

    /// The folder native screenshots are currently saved to.
    static var location: URL {
        if let value = CFPreferencesCopyAppValue(key, domain) as? String {
            let expanded = (value as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return URL(fileURLWithPath: expanded)
            }
        }
        // macOS default when the preference is unset.
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    static func setLocation(_ url: URL) {
        CFPreferencesSetAppValue(key, url.path as CFString, domain)
        CFPreferencesAppSynchronize(domain)
        restartSystemUIServer()
    }

    /// `screencapture` caches the location; restarting SystemUIServer makes
    /// the change take effect immediately. Harmless — it relaunches instantly.
    private static func restartSystemUIServer() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["SystemUIServer"]
        try? process.run()
    }
}
