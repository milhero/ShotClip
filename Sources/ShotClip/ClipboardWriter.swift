import AppKit

/// Writes a screenshot to the general pasteboard as a *single* pasteboard
/// item carrying two representations:
///
/// - `public.file-url` — pasting into Finder, Slack, Mail etc. inserts the file
/// - `public.png`      — pasting into image editors, browsers etc. inserts the image
///
/// Receiving apps automatically pick the richest representation they support.
enum ClipboardWriter {

    @discardableResult
    static func copy(_ url: URL, includeImage: Bool, includeFile: Bool) -> Bool {
        guard includeImage || includeFile else { return false }

        let item = NSPasteboardItem()
        var wroteSomething = false

        if includeFile {
            item.setString(url.absoluteString, forType: .fileURL)
            wroteSomething = true
        }

        if includeImage, let png = pngData(for: url) {
            item.setData(png, forType: .png)
            wroteSomething = true
        }

        guard wroteSomething else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }

    /// Returns PNG data for the file. Screenshots are PNG by default, but the
    /// user may have changed the capture format (jpg, tiff, …) — convert then.
    private static func pngData(for url: URL) -> Data? {
        if url.pathExtension.lowercased() == "png" {
            return try? Data(contentsOf: url)
        }
        guard
            let image = NSImage(contentsOf: url),
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
