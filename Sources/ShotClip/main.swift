import AppKit

// Headless helper used by `make install` / scripts:
//   ShotClip --enable-login
// registers the app as a login item and exits without starting the UI, so the
// menu bar app can be set to launch at login from the command line. It prints
// the resulting status ("enabled" or "needs-approval") for the caller.
if CommandLine.arguments.contains("--enable-login") {
    do {
        try LoginItem.setEnabled(true)
        let status = LoginItem.isEnabled ? "enabled" : "needs-approval"
        FileHandle.standardOutput.write(Data("ShotClip login item: \(status)\n".utf8))
        exit(0)
    } catch {
        FileHandle.standardError.write(
            Data("ShotClip: could not enable login item: \(error.localizedDescription)\n".utf8)
        )
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
