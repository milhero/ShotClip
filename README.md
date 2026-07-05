# ShotClip

macOS saves a screenshot to disk *or* copies it to the clipboard, never both. ShotClip does both: take a screenshot with the native shortcuts (⌘⇧3/4/5) and it lands in your folder and on your clipboard.

A menu bar app. No new shortcuts, no screen recording permission, no polling.

## Install

Requires macOS 13+ and the Xcode Command Line Tools.

```sh
git clone https://github.com/YOURNAME/ShotClip.git
cd ShotClip
make install
```

macOS will ask once for access to your screenshot folder.

## Settings

Everything is in the menu bar icon and under Settings…:

- Screenshot folder — sets the native save location, so it applies system-wide
- Copy as image / as file — both by default: image editors paste pixels, Finder and Slack paste the file
- Hide the menu bar icon — launch ShotClip again to reopen the settings window
- Launch at login

## How it works

`screencapture` writes a temp file first and renames it afterwards, which is why folder-watching scripts are unreliable. ShotClip instead listens to Spotlight for `kMDItemIsScreenCapture == 1`, which only fires for finished, real screenshots. The saving itself is done by macOS.

## Troubleshooting

- Nothing copied: Spotlight indexing must be enabled for the screenshot folder.
- Launch at login fails: install via `make install`, don't run from the build directory.

## License

MIT
