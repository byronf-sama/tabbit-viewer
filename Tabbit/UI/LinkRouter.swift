import AppKit

/// Where links (and any other navigation away from the shown document) go:
/// web links to the default browser, local Markdown/HTML files to a new tab,
/// other local files and folders to their default app (or Finder).
enum LinkRouter {
    static let documentExtensions: Set<String> = ["md", "markdown", "html", "htm"]

    /// The local file a `file:` or `tabbit-file:` URL points at (without query or fragment).
    static func localFileURL(for url: URL) -> URL? {
        if url.isFileURL {
            return URL(filePath: url.path(percentEncoded: false)).standardizedFileURL
        }
        return LocalFileSchemeHandler.fileURL(for: url)
    }

    static func open(_ url: URL) {
        guard let fileURL = localFileURL(for: url) else {
            NSWorkspace.shared.open(url)
            return
        }
        if documentExtensions.contains(fileURL.pathExtension.lowercased()) {
            NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) { _, _, error in
                if let error { NSApp.presentError(error) }
            }
        } else if !NSWorkspace.shared.open(fileURL) {
            NSSound.beep()
        }
    }
}
