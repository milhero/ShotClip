import Foundation

/// Watches for new screenshots using Spotlight (`NSMetadataQuery`).
///
/// Why Spotlight instead of FSEvents / Folder Actions / launchd WatchPaths:
/// `screencapture` first writes a hidden temporary file and then renames it.
/// Naive file watchers fire too early (file incomplete), twice, or not at
/// all — this is the classic reason shell-script solutions are flaky.
/// Spotlight only indexes the *finished* file and exposes the dedicated
/// `kMDItemIsScreenCapture` attribute, which macOS sets exclusively for
/// screenshots taken with the native shortcuts (⌘⇧3 / ⌘⇧4 / ⌘⇧5).
final class ScreenshotWatcher: NSObject {

    /// Called on the main queue with the URL of each newly saved screenshot.
    var onScreenshot: ((URL) -> Void)?

    private var query: NSMetadataQuery?
    private var processedPaths = Set<String>()
    private var startDate = Date()

    /// (Re)starts watching the given folder. Safe to call repeatedly,
    /// e.g. after the user changes the screenshot folder.
    func start(in folder: URL) {
        stop()
        startDate = Date()

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [folder]
        query.operationQueue = .main
        query.notificationBatchingInterval = 0.2

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        self.query = query
        query.start()
    }

    func stop() {
        guard let query else { return }
        query.stop()
        NotificationCenter.default.removeObserver(self, name: nil, object: query)
        self.query = nil
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        let changed = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
        process(added + changed)
    }

    /// A screenshot saved while the initial gathering is still running is
    /// part of the gather results and never shows up in a `DidUpdate`
    /// notification — without this it would be dropped (matters right after
    /// launch and after a folder change).
    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.disableUpdates()
        let items = (0..<query.resultCount).compactMap { query.result(at: $0) as? NSMetadataItem }
        query.enableUpdates()
        process(items)
    }

    private func process(_ items: [NSMetadataItem]) {
        for item in items {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !processedPaths.contains(path),
                  FileManager.default.fileExists(atPath: path)
            else { continue }

            // Ignore screenshots that already existed before watching started —
            // both those from before launch and, after a folder change, old
            // screenshots already sitting in the newly selected folder.
            let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .distantPast
            guard created >= startDate else { continue }

            processedPaths.insert(path)
            onScreenshot?(URL(fileURLWithPath: path))
        }
    }

    deinit {
        stop()
    }
}
