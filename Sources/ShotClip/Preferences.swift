import Foundation

/// UserDefaults keys shared between the menu and the settings window.
enum Prefs {
    static let copyImage = "copyImage"
    static let copyFile = "copyFile"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let instantCapture = "instantCapture" // disable the floating thumbnail

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            copyImage: true,
            copyFile: true,
            showMenuBarIcon: true,
            instantCapture: true,
        ])
    }
}
