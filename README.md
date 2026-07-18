# ShotClip

macOS saves a screenshot to disk *or* copies it to the clipboard, never both. ShotClip does both: take a screenshot with the native shortcuts (⌘⇧3/4/5) and it lands in your folder and on your clipboard.

A menu bar app. No new shortcuts, no screen recording permission, no polling.

## Download

Grab `ShotClip-vX.Y.Z.zip` from the [latest release](https://github.com/milhero/ShotClip/releases/latest), unzip, and move ShotClip.app to /Applications. The app is not notarized, so on first launch allow it under System Settings → Privacy & Security.

## Build from source

Requires macOS 13+ and the Xcode Command Line Tools.

```sh
git clone https://github.com/milhero/ShotClip.git
cd ShotClip
make install
```

macOS will ask once for access to your screenshot folder.

## Settings

Everything is in the menu bar icon and under Settings…:

- Screenshot folder — sets the native save location, so it applies system-wide
- Clean Screenshot Folder — moves every screenshot in the folder to the Trash (with a confirmation); only files macOS marks as screenshots are touched, so other files are left alone
- Instant Capture — on by default; turns off macOS's floating thumbnail so the screenshot is written to disk (and copied) immediately instead of ~5 s later. Turn it off if you want the thumbnail/markup back
- Copy as image / as file — both by default: image editors paste pixels, Finder and Slack paste the file
- Hide the menu bar icon — launch ShotClip again to reopen the settings window
- Launch at login

## How it works

ShotClip watches your screenshot folder with a kqueue directory source, so a new screenshot is picked up within milliseconds of being saved and lands on the clipboard immediately. `screencapture` writes a hidden temp file and then atomically renames it to the final name, so ShotClip ignores hidden files and only acts on the finished file — it never reads a half-written image. A low-frequency poll runs as a backstop in case a file-system event is ever missed. The saving itself is done by macOS.

(Earlier versions detected screenshots via Spotlight's `kMDItemIsScreenCapture` attribute; that was reliable but added a ~1–2 s indexing lag, which is why a screenshot sometimes reached the clipboard only after the next one was taken.)

## Troubleshooting

- Nothing copied: make sure the screenshot folder in Settings matches your actual save location (⌘⇧5 ▸ Options ▸ Save to).
- Launch at login fails: install via `make install`, don't run from the build directory.
- Launch at login looks on but doesn't fire: macOS often registers the app as *needs approval* — switch ShotClip on under System Settings ▸ General ▸ Login Items. The menu shows "(needs approval)" in this state. Because each `make install` re-signs the app ad-hoc, you may need to re-approve after reinstalling.

## License

MIT
