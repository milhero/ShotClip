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
    private let launchDate = Date()

    /// (Re)starts watching the given folder. Safe to call repeatedly,
    /// e.g. after the user changes the screenshot folder.
    func start(in folder: URL) {
        stop()

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

        for item in added + changed {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !processedPaths.contains(path),
                  FileManager.default.fileExists(atPath: path)
            else { continue }

            // Ignore screenshots that already existed before the app started.
            let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .distantPast
            guard created >= launchDate else { continue }

            processedPaths.insert(path)
            onScreenshot?(URL(fileURLWithPath: path))
        }
    }

    deinit {
        stop()
    }
}
