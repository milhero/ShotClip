import Foundation

/// Watches the screenshot folder and reports each newly saved screenshot.
///
/// Detection uses a **kqueue directory watch** (`DispatchSource` file-system
/// source), which fires within milliseconds of a file appearing — unlike the
/// previous Spotlight/`NSMetadataQuery` approach, whose live-update indexing
/// lag (~1–2 s) meant a screenshot only reached the clipboard a beat late. That
/// lag is exactly why "the first screenshot keeps the old clipboard, only the
/// second one lands": the copy was simply arriving after the user already
/// pasted or shot again.
///
/// `screencapture` writes a hidden temp file and then atomically renames it to
/// the final name. We ignore hidden files and only act on the finished,
/// visible file, so we never read a half-written screenshot. A low-frequency
/// poll runs as a backstop in case a kqueue event is ever missed, so detection
/// is instant in the common case and guaranteed within a couple of seconds
/// worst case.
final class ScreenshotWatcher: NSObject {

    /// Called on the main queue with the URL of each newly saved screenshot.
    var onScreenshot: ((URL) -> Void)?

    private var watchedFolder: URL?
    private var seenPaths = Set<String>()

    private var dirSource: DispatchSourceFileSystemObject?
    private var backstopTimer: DispatchSourceTimer?

    /// Formats `screencapture` can produce (png is the default; the user may
    /// have switched via `defaults write com.apple.screencapture type`).
    private static let captureExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "heif", "pdf", "bmp",
    ]

    /// (Re)starts watching the given folder. Safe to call repeatedly,
    /// e.g. after the user changes the screenshot folder.
    func start(in folder: URL) {
        stop()
        watchedFolder = folder

        // Baseline: remember everything already in the folder so only
        // screenshots taken from now on are ever delivered.
        seenPaths = Set(files(in: folder).map(\.path))

        startDirectoryWatch(folder)
        startBackstopTimer()
    }

    func stop() {
        backstopTimer?.cancel()
        backstopTimer = nil
        dirSource?.cancel() // the cancel handler closes the file descriptor
        dirSource = nil
        watchedFolder = nil
    }

    // MARK: - Fast path: kqueue directory watch

    private func startDirectoryWatch(_ folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.scan() }
        source.setCancelHandler { close(fd) } // capture this fd, not a mutable field
        dirSource = source
        source.resume()
    }

    // MARK: - Backstop: catches anything the kqueue event might miss

    private func startBackstopTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.scan() }
        backstopTimer = timer
        timer.resume()
    }

    // MARK: - Scanning

    private func scan() {
        guard let folder = watchedFolder else { return }
        for url in files(in: folder) {
            process(url)
        }
    }

    /// Delivers a screenshot exactly once. A file still mid-rename (not yet on
    /// disk) is left unmarked so the next event retries it; non-image files are
    /// marked seen and skipped.
    private func process(_ url: URL) {
        let path = url.path
        guard !seenPaths.contains(path) else { return }
        guard FileManager.default.fileExists(atPath: path) else { return }
        seenPaths.insert(path)
        guard Self.captureExtensions.contains(url.pathExtension.lowercased()) else { return }
        onScreenshot?(url)
    }

    private func files(in folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )) ?? []
    }

    deinit {
        stop()
    }
}
