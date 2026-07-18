import AppKit

/// Programmatic AppKit settings window — the alternative to the menu bar
/// icon for users who prefer a clean menu bar. Reached via "Settings…" in
/// the menu, or (when the icon is hidden) by launching ShotClip again.
final class SettingsWindowController: NSWindowController {

    var onSettingsChanged: (() -> Void)?
    var onChangeFolder: (() -> Void)?
    var onOpenFolder: (() -> Void)?
    var onCleanFolder: (() -> Void)?

    private let defaults = UserDefaults.standard

    private let folderLabel = NSTextField(labelWithString: "")
    private let showIconCheckbox = NSButton(checkboxWithTitle: "Show menu bar icon", target: nil, action: nil)
    private let copyImageCheckbox = NSButton(checkboxWithTitle: "Copy as image", target: nil, action: nil)
    private let copyFileCheckbox = NSButton(checkboxWithTitle: "Copy as file", target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShotClip Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func refresh() {
        folderLabel.stringValue = (ScreenCaptureDefaults.location.path as NSString).abbreviatingWithTildeInPath
        showIconCheckbox.state = defaults.bool(forKey: Prefs.showMenuBarIcon) ? .on : .off
        copyImageCheckbox.state = defaults.bool(forKey: Prefs.copyImage) ? .on : .off
        copyFileCheckbox.state = defaults.bool(forKey: Prefs.copyFile) ? .on : .off

        if LoginItem.isEnabled {
            loginCheckbox.state = .on
            loginCheckbox.title = "Launch at login"
        } else if LoginItem.requiresApproval {
            loginCheckbox.state = .mixed
            loginCheckbox.title = "Launch at login (approve in System Settings)"
        } else {
            loginCheckbox.state = .off
            loginCheckbox.title = "Launch at login"
        }
    }

    // MARK: - UI

    private func buildUI() {
        for (checkbox, action) in [
            (showIconCheckbox, #selector(toggleShowIcon)),
            (copyImageCheckbox, #selector(toggleCopyImage)),
            (copyFileCheckbox, #selector(toggleCopyFile)),
            (loginCheckbox, #selector(toggleLogin)),
        ] {
            checkbox.target = self
            checkbox.action = action
        }

        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.textColor = .secondaryLabelColor

        let changeButton = NSButton(title: "Change…", target: self, action: #selector(changeFolderClicked))
        let openButton = NSButton(title: "Open in Finder", target: self, action: #selector(openFolderClicked))
        let cleanButton = NSButton(title: "Clean Folder…", target: self, action: #selector(cleanFolderClicked))
        let buttonRow = NSStackView(views: [changeButton, openButton, cleanButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let hint = NSTextField(wrappingLabelWithString:
            "When the menu bar icon is hidden, launch ShotClip again (e.g. via Spotlight) to reopen this window.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 380

        let stack = NSStackView(views: [
            sectionLabel("Screenshot Folder"),
            folderLabel,
            buttonRow,
            separator(),
            sectionLabel("Clipboard"),
            copyImageCheckbox,
            copyFileCheckbox,
            separator(),
            sectionLabel("General"),
            showIconCheckbox,
            hint,
            loginCheckbox,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        window?.contentView = stack

        folderLabel.translatesAutoresizingMaskIntoConstraints = false
        folderLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true
        for view in stack.arrangedSubviews where view is NSBox {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: 400).isActive = true
        }

        let height = stack.fittingSize.height
        window?.setContentSize(NSSize(width: 440, height: max(height, 300)))
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    // MARK: - Actions

    @objc private func toggleShowIcon() {
        defaults.set(showIconCheckbox.state == .on, forKey: Prefs.showMenuBarIcon)
        onSettingsChanged?()
    }

    @objc private func toggleCopyImage() {
        defaults.set(copyImageCheckbox.state == .on, forKey: Prefs.copyImage)
    }

    @objc private func toggleCopyFile() {
        defaults.set(copyFileCheckbox.state == .on, forKey: Prefs.copyFile)
    }

    @objc private func toggleLogin() {
        let turnOn = !LoginItem.isEnabled
        do {
            try LoginItem.setEnabled(turnOn)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change login item"
            alert.informativeText = """
            \(error.localizedDescription)

            ShotClip must run as an app bundle from /Applications \
            (use “make install”).
            """
            alert.runModal()
            refresh()
            return
        }

        if turnOn, LoginItem.requiresApproval {
            let alert = NSAlert()
            alert.messageText = "One more step to launch at login"
            alert.informativeText = """
            macOS needs you to switch ShotClip on under \
            System Settings ▸ General ▸ Login Items.
            """
            alert.addButton(withTitle: "Open Login Items")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                LoginItem.openSettings()
            }
        }
        refresh()
    }

    @objc private func changeFolderClicked() {
        onChangeFolder?()
    }

    @objc private func openFolderClicked() {
        onOpenFolder?()
    }

    @objc private func cleanFolderClicked() {
        onCleanFolder?()
    }
}
