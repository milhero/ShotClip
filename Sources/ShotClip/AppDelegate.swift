import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private let watcher = ScreenshotWatcher()
    private let defaults = UserDefaults.standard

    private lazy var settingsWindow: SettingsWindowController = {
        let controller = SettingsWindowController()
        controller.onSettingsChanged = { [weak self] in self?.applySettings() }
        controller.onChangeFolder = { [weak self] in self?.changeFolder() }
        controller.onOpenFolder = { [weak self] in self?.openFolder() }
        return controller
    }()

    private var lastCaptureItem: NSMenuItem?
    private var folderItem: NSMenuItem?
    private var copyImageItem: NSMenuItem?
    private var copyFileItem: NSMenuItem?
    private var pauseItem: NSMenuItem?
    private var loginMenuItem: NSMenuItem?

    private var isPaused = false
    private var lastCaptureTitle = "No screenshots yet"

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        applySettings()
        watcher.onScreenshot = { [weak self] url in self?.handleScreenshot(url) }
        watcher.start(in: ScreenCaptureDefaults.location)
    }

    /// Launching ShotClip again while it is running (Spotlight, Finder, …)
    /// lands here — the standard way back to the UI when the menu bar icon
    /// is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    // MARK: - Settings

    /// Creates or removes the status item according to the preference.
    private func applySettings() {
        let show = defaults.bool(forKey: Prefs.showMenuBarIcon)
        if show, statusItem == nil {
            setUpStatusItem()
        } else if !show, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - Screenshot handling

    private func handleScreenshot(_ url: URL) {
        guard !isPaused else { return }
        let ok = ClipboardWriter.copy(
            url,
            includeImage: defaults.bool(forKey: Prefs.copyImage),
            includeFile: defaults.bool(forKey: Prefs.copyFile)
        )
        lastCaptureTitle = ok
            ? "Copied “\(url.lastPathComponent)”"
            : "Failed to copy “\(url.lastPathComponent)”"
        lastCaptureItem?.title = lastCaptureTitle
        flashIcon(success: ok)
    }

    // MARK: - Status item & menu

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        setIcon("camera.viewfinder")

        let menu = NSMenu()
        menu.delegate = self

        let last = NSMenuItem(title: lastCaptureTitle, action: nil, keyEquivalent: "")
        menu.addItem(last)
        lastCaptureItem = last
        menu.addItem(.separator())

        folderItem = menu.addItem(
            withTitle: "Open Screenshot Folder",
            action: #selector(openFolder),
            keyEquivalent: "o"
        )
        folderItem?.target = self

        let changeItem = menu.addItem(
            withTitle: "Change Screenshot Folder…",
            action: #selector(changeFolder),
            keyEquivalent: ""
        )
        changeItem.target = self
        menu.addItem(.separator())

        copyImageItem = menu.addItem(
            withTitle: "Copy as Image",
            action: #selector(toggleCopyImage),
            keyEquivalent: ""
        )
        copyImageItem?.target = self

        copyFileItem = menu.addItem(
            withTitle: "Copy as File",
            action: #selector(toggleCopyFile),
            keyEquivalent: ""
        )
        copyFileItem?.target = self

        pauseItem = menu.addItem(
            withTitle: "Pause",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem?.target = self
        menu.addItem(.separator())

        loginMenuItem = menu.addItem(
            withTitle: "Launch at Login",
            action: #selector(toggleLogin),
            keyEquivalent: ""
        )
        loginMenuItem?.target = self

        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(.separator())

        let quitItem = menu.addItem(
            withTitle: "Quit ShotClip",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp

        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        copyImageItem?.state = defaults.bool(forKey: Prefs.copyImage) ? .on : .off
        copyFileItem?.state = defaults.bool(forKey: Prefs.copyFile) ? .on : .off
        pauseItem?.state = isPaused ? .on : .off
        loginMenuItem?.state = LoginItem.isEnabled ? .on : .off

        let tildePath = (ScreenCaptureDefaults.location.path as NSString).abbreviatingWithTildeInPath
        folderItem?.title = "Open “\(tildePath)”"
    }

    private func setIcon(_ symbolName: String) {
        statusItem?.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "ShotClip"
        )
    }

    private func flashIcon(success: Bool) {
        guard statusItem != nil else { return }
        setIcon(success ? "checkmark.circle" : "exclamationmark.circle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.setIcon("camera.viewfinder")
        }
    }

    // MARK: - Actions

    @objc private func showSettings() {
        settingsWindow.show()
    }

    @objc private func openFolder() {
        NSWorkspace.shared.open(ScreenCaptureDefaults.location)
    }

    @objc private func changeFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use for Screenshots"
        panel.message = "New screenshots (⌘⇧3 / ⌘⇧4 / ⌘⇧5) will be saved here."
        panel.directoryURL = ScreenCaptureDefaults.location
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ScreenCaptureDefaults.setLocation(url)
        watcher.start(in: url)
        settingsWindow.refresh()
    }

    @objc private func toggleCopyImage() {
        defaults.set(!defaults.bool(forKey: Prefs.copyImage), forKey: Prefs.copyImage)
    }

    @objc private func toggleCopyFile() {
        defaults.set(!defaults.bool(forKey: Prefs.copyFile), forKey: Prefs.copyFile)
    }

    @objc private func togglePause() {
        isPaused.toggle()
    }

    @objc private func toggleLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Could not change login item"
            alert.informativeText = """
            \(error.localizedDescription)

            Note: this only works when ShotClip runs as a proper .app bundle \
            from /Applications (use “make install”).
            """
            alert.runModal()
        }
    }
}
