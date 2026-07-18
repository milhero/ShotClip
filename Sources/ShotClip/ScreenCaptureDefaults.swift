import Foundation

/// Reads and writes the native macOS screenshot save location — the
/// `com.apple.screencapture` preference domain used by ⌘⇧3 / ⌘⇧4 / ⌘⇧5.
///
/// Because macOS itself saves the file there, the "save to folder" half of
/// the workflow is 100% native and needs no code at capture time.
enum ScreenCaptureDefaults {

    private static let domain = "com.apple.screencapture" as CFString
    private static let key = "location" as CFString
    private static let thumbnailKey = "show-thumbnail" as CFString

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

    /// Whether macOS shows the floating thumbnail after a capture. While the
    /// thumbnail floats (~5 s), macOS delays writing the file to disk — which
    /// is exactly what makes the screenshot reach the clipboard seconds late.
    /// Defaults to `true` (macOS's own default when the key is unset).
    static var showsThumbnail: Bool {
        let value = CFPreferencesCopyAppValue(thumbnailKey, domain)
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return true
    }

    static func setShowsThumbnail(_ shows: Bool) {
        let value: CFBoolean = shows ? kCFBooleanTrue : kCFBooleanFalse
        CFPreferencesSetAppValue(thumbnailKey, value, domain)
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
