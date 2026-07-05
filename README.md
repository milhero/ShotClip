# ShotClip

**Native macOS screenshots → your folder *and* your clipboard.**

macOS makes you choose: `⌘⇧3` saves a screenshot to disk, `⌃⌘⇧3` copies it to the clipboard — but never both. ShotClip is a tiny menu bar app that removes that trade-off. Take a screenshot with any native shortcut and it lands in your chosen folder **and** in your clipboard, every time.

No new shortcuts to learn. No screen recording permission. No background CPU polling.

## Why it's reliable (and why scripts aren't)

If you've ever tried this with Folder Actions, Automator, or a `launchd` WatchPaths script, you've probably seen it fire too early, twice, or not at all. That's because `screencapture` first writes a hidden temporary file and then renames it — naive file watchers race against that rename and read incomplete files.

ShotClip instead subscribes to **Spotlight** via `NSMetadataQuery` with the predicate `kMDItemIsScreenCapture == 1`:

- Spotlight only indexes the *finished* file — no race conditions, ever.
- `kMDItemIsScreenCapture` is set by macOS exclusively for native screenshots, so other files landing in the folder are ignored.
- It's push-based: zero polling, effectively zero resource usage.

The "save to folder" half needs no code at all: ShotClip simply manages the native `com.apple.screencapture location` preference, so macOS itself does the saving.

## Install

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/YOURNAME/ShotClip.git
cd ShotClip
make install
```

That builds the app, ad-hoc signs it, copies it to `/Applications`, and launches it. Look for the camera icon in the menu bar.

On the first screenshot, macOS will ask ShotClip for permission to access your screenshot folder (e.g. Desktop) — allow it once and you're done.

## Usage

Everything is reachable from the menu bar icon and the settings window (menu → **Settings…**):

- **Open / Change Screenshot Folder** — sets the *native* save location (same as `defaults write com.apple.screencapture location`), so it applies to `⌘⇧3/4/5` system-wide.
- **Copy as Image / Copy as File** — what goes on the clipboard. Both are on by default: a single clipboard entry with two representations, so Finder/Slack paste the file while image editors paste the pixels.
- **Pause** — temporarily stop copying without quitting.
- **Launch at Login** — registers via `SMAppService` (requires the app to run from `/Applications`).
- **Show menu bar icon** — prefer a clean menu bar? Hide the icon entirely; ShotClip keeps working in the background. To get the settings window back, just launch ShotClip again (Spotlight or the Applications folder) — the running instance opens it.

Note: if the floating thumbnail preview is enabled (⌘⇧5 → Options), macOS writes the file only after the thumbnail disappears — the clipboard fills at that moment.

## Project layout

```
Sources/ShotClip/
├── main.swift                      # entry point (accessory app, no Dock icon)
├── AppDelegate.swift               # menu bar UI, reopen handling
├── SettingsWindowController.swift  # settings window (AppKit, programmatic)
├── ScreenshotWatcher.swift         # Spotlight (NSMetadataQuery) watcher
├── ClipboardWriter.swift           # NSPasteboard: file-URL + PNG in one item
├── ScreenCaptureDefaults.swift     # native screenshot-location preference
├── Preferences.swift               # shared UserDefaults keys
└── LoginItem.swift                 # SMAppService wrapper
Resources/Info.plist                # LSUIElement bundle metadata
Resources/AppIcon.png               # 1024px master icon (.icns built via sips/iconutil)
Makefile                            # build / icon / app bundle / install
```

## Troubleshooting

- **Nothing is copied** — check that Spotlight indexing is enabled for the screenshot folder (System Settings → Siri & Spotlight → Spotlight Privacy). ShotClip depends on Spotlight.
- **"Launch at Login" fails** — the app must run as a bundle from `/Applications`; use `make install`, not `swift run`.
- **Folder change doesn't stick** — ShotClip restarts `SystemUIServer` automatically; if a third-party screenshot tool also manages this preference, disable one of the two.

## Releasing

For a public release beyond `git clone && make install`:

1. Sign with a Developer ID certificate instead of ad-hoc (`codesign --sign "Developer ID Application: …"`), then notarize with `xcrun notarytool submit` — otherwise Gatekeeper blocks downloaded copies.
2. Ship a zip/DMG via GitHub Releases and add a Homebrew cask so users can `brew install --cask shotclip`.

## License

[MIT](LICENSE)
