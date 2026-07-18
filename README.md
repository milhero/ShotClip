# ShotClip

macOS saves a screenshot to a file *or* copies it to the clipboard — never both. ShotClip does both: press the native shortcuts (⌘⇧3/4/5) and the screenshot lands in your folder **and** on your clipboard, instantly.

A tiny menu bar app. No new shortcuts, no screen recording permission, no Electron, no subscription.

<!-- ![demo](docs/demo.gif) -->

## Install

Download `ShotClip.zip` from the [latest release](https://github.com/milhero/ShotClip/releases/latest), unzip, drop it in /Applications. Not notarized — first launch via right-click → Open.

Or build it yourself (macOS 13+, Xcode Command Line Tools):

```sh
git clone https://github.com/milhero/ShotClip.git && cd ShotClip && make install
```

## Settings

All in the menu bar icon:

- **Screenshot folder** — sets the native save location, system-wide
- **Instant Capture** (default on) — disables the floating thumbnail; that thumbnail is why macOS otherwise writes the file ~5 s late
- **Clean Screenshot Folder** — trashes all screenshots in the folder, nothing else
- **Copy as image / as file** — editors paste pixels, Finder/Slack paste the file
- Launch at login, hide the menu bar icon

## How it works

macOS itself captures and saves — ShotClip just watches the folder with a kqueue source and copies each finished file within milliseconds. `screencapture` writes a hidden temp file first and renames it when done, so half-written images are never touched. A slow poll backstops missed events.

Earlier versions used Spotlight (`kMDItemIsScreenCapture`), which added 1–2 s of indexing lag — that's gone.

## Troubleshooting

- Nothing copied → check the folder in Settings matches ⌘⇧5 ▸ Options ▸ Save to
- Launch at login "on" but not firing → approve ShotClip under System Settings ▸ Login Items (needed again after reinstalls, ad-hoc signing)

## License

MIT
