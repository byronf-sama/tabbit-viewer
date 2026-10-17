import AppKit

/// Tabbit only opens existing files, so the "new document" entry points
/// (⌘N, the tab bar's + button) show the Open panel instead.
final class TabbitDocumentController: NSDocumentController {
    override func newDocument(_ sender: Any?) {
        openDocument(sender)
    }

    /// Its presence in the responder chain is what makes AppKit show the tab bar's + button.
    @IBAction func newWindowForTab(_ sender: Any?) {
        openDocument(sender)
    }
}
