import AppKit
import CoreServices

/// Moves screenshot files out of the screenshot folder and into the Trash.
///
/// Only files macOS itself marks as screenshots (`kMDItemIsScreenCapture == 1`)
/// are touched — the same Spotlight attribute `ScreenshotWatcher` uses to
/// detect new captures — so unrelated files sitting in the same folder are
/// never removed. Deleted files go to the Trash, not `unlink`, so a mistaken
/// clean is always recoverable.
enum ScreenshotCleaner {

    /// The screenshots currently sitting in `folder`, newest first.
    static func screenshots(in folder: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        return entries
            .filter(isScreenshot)
            .sorted { modificationDate($0) > modificationDate($1) }
    }

    /// Moves the given files to the Trash. Returns the number actually moved.
    @discardableResult
    static func moveToTrash(_ urls: [URL]) -> Int {
        let fm = FileManager.default
        var moved = 0
        for url in urls {
            // Best-effort: skip anything that can't be moved (already gone,
            // permissions) rather than aborting the whole clean.
            if (try? fm.trashItem(at: url, resultingItemURL: nil)) != nil {
                moved += 1
            }
        }
        return moved
    }

    // MARK: - Private

    /// True when Spotlight marks the file as a native screenshot.
    private static func isScreenshot(_ url: URL) -> Bool {
        guard
            let item = MDItemCreateWithURL(nil, url as CFURL),
            let value = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString)
        else { return false }

        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
    }
}
