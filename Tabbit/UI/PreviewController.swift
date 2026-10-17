import AppKit
import WebKit

/// View mode: a WKWebView showing the rendered document.
///
/// - Markdown is rendered by a bundled page (web/markdown.html) served at the file's own path
///   over `tabbit-file:` (see LocalFileSchemeHandler), so relative images and links resolve
///   against the file's folder. The page stays loaded; new text goes to `window.tabbit.render`,
///   which keeps the scroll position.
/// - HTML is loaded from disk with read access to the file's folder, as a browser would. Unsaved
///   edits are loaded as if they were the file's contents (same URL, same folder access).
/// - Navigating away from the document never happens in place: see LinkRouter.
final class PreviewController: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private let document: TabbitDocument
    private let schemeHandler = LocalFileSchemeHandler(pageHTML: PreviewController.markdownPage)
    private let uiDelegate = PageUIDelegate()

    /// The text currently shown (or about to be shown once the page finishes loading).
    private var text = ""
    private var textIsSaved = true
    /// The file the page was last loaded for, and the text it showed.
    private var shownFileURL: URL?
    private var shownText: String?
    private var markdownPageReady = false
    /// Whether this web view's content process has been granted read access to the HTML file's
    /// folder (by a loadFileURL). Loading unsaved edits relies on it.
    private var htmlFolderAccess: URL?
    /// Edited HTML waiting for the folder-access load to finish.
    private var pendingUnsavedHTML: String?
    /// Scroll position to restore after reloading an HTML page.
    private var pendingScroll: (x: Double, y: Double)?

    private static let markdownPage: String = {
        guard let url = Bundle.main.url(forResource: "markdown", withExtension: "html", subdirectory: "web"),
              let html = try? String(contentsOf: url, encoding: .utf8) else {
            return "<p>web/markdown.html is missing from the app bundle. Run <code>npm run build</code> in web/.</p>"
        }
        return html
    }()

    init(document: TabbitDocument) {
        self.document = document
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: LocalFileSchemeHandler.scheme)
        webView = TabbitWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = uiDelegate
        webView.allowsMagnification = true
        webView.isInspectable = true
        // Invisible until the first content is in, to avoid a white flash in dark mode.
        webView.alphaValue = 0
    }

    /// Shows `text` as the document's content. `isSaved` says whether it matches the file on disk.
    func show(_ text: String, isSaved: Bool) {
        guard let fileURL = document.fileURL else { return }
        if fileURL == shownFileURL, text == shownText { return }
        self.text = text
        textIsSaved = isSaved
        switch document.kind {
        case .markdown: showMarkdown(fileURL)
        case .html: showHTML(fileURL, isSaved: isSaved)
        }
    }

    // MARK: Markdown

    private func showMarkdown(_ fileURL: URL) {
        if fileURL != shownFileURL {
            // First show, or the file moved (Save As, rename): (re)load the page; didFinish renders.
            guard let pageURL = LocalFileSchemeHandler.schemeURL(for: fileURL) else { return }
            shownFileURL = fileURL
            markdownPageReady = false
            schemeHandler.documentURL = fileURL
            webView.load(URLRequest(url: pageURL))
        } else if markdownPageReady {
            renderMarkdown()
        }
    }

    private func renderMarkdown() {
        shownText = text
        webView.callAsyncJavaScript("window.tabbit.render(text)", arguments: ["text": text],
                                    in: nil, in: .page) { [weak self] result in
            if case .failure(let error) = result {
                NSLog("Tabbit: Markdown render failed: \(error)")
            }
            self?.webView.alphaValue = 1
        }
    }

    // MARK: HTML

    private func showHTML(_ fileURL: URL, isSaved: Bool) {
        // Hand WebKit the URLs as they are: standardizing would turn /private/tmp/… into /tmp/…,
        // and the file would no longer be inside the folder it was granted access to.
        let folder = fileURL.deletingLastPathComponent()
        let reloadingSamePage = fileURL == shownFileURL
        shownFileURL = fileURL
        shownText = text

        let load = { [self] in
            if isSaved || htmlFolderAccess != folder.standardizedFileURL {
                // From disk; this also grants the content process read access to the folder.
                // Unsaved edits wait for it to finish (see didFinish).
                pendingUnsavedHTML = isSaved ? nil : text
                htmlFolderAccess = nil
                webView.loadFileURL(fileURL, allowingReadAccessTo: folder)
            } else {
                webView.loadSimulatedRequest(URLRequest(url: fileURL), responseHTML: text)
            }
        }
        guard reloadingSamePage else { return load() }
        webView.evaluateJavaScript("[window.scrollX, window.scrollY]") { [weak self] result, _ in
            if let position = result as? [Double], position.count == 2 {
                self?.pendingScroll = (position[0], position[1])
            }
            load()
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        // Iframes load whatever the page asks for.
        if let frame = navigationAction.targetFrame, !frame.isMainFrame { return decisionHandler(.allow) }
        // The document itself: the initial load, reloads, and #fragment links within it.
        if navigationAction.targetFrame != nil, isDocument(url) { return decisionHandler(.allow) }
        decisionHandler(.cancel)
        LinkRouter.open(url)
    }

    private func isDocument(_ url: URL) -> Bool {
        guard let documentURL = document.fileURL?.standardizedFileURL else { return false }
        switch document.kind {
        case .markdown: guard url.scheme == LocalFileSchemeHandler.scheme else { return false }
        case .html: guard url.isFileURL else { return false }
        }
        return LinkRouter.localFileURL(for: url) == documentURL
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        switch document.kind {
        case .markdown:
            // Also covers a reload from the context menu, which brings back the empty page.
            markdownPageReady = true
            renderMarkdown()
        case .html:
            if let url = webView.url, url.isFileURL, htmlFolderAccess == nil {
                htmlFolderAccess = url.deletingLastPathComponent().standardizedFileURL
            }
            if let unsaved = pendingUnsavedHTML, let fileURL = shownFileURL {
                pendingUnsavedHTML = nil
                webView.loadSimulatedRequest(URLRequest(url: fileURL), responseHTML: unsaved)
                return
            }
            if let scroll = pendingScroll {
                pendingScroll = nil
                webView.evaluateJavaScript("window.scrollTo(\(scroll.x), \(scroll.y))")
            }
            webView.alphaValue = 1
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadFailed()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFailed()
    }

    private func loadFailed() {
        // If the folder-access load failed, still show the edits (relative resources may not load).
        if let unsaved = pendingUnsavedHTML, let fileURL = shownFileURL {
            pendingUnsavedHTML = nil
            webView.loadSimulatedRequest(URLRequest(url: fileURL), responseHTML: unsaved)
        }
        webView.alphaValue = 1
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // A new content process has no folder access and no rendered page: start over.
        htmlFolderAccess = nil
        markdownPageReady = false
        shownFileURL = nil
        shownText = nil
        show(text, isSaved: textIsSaved)
    }
}
