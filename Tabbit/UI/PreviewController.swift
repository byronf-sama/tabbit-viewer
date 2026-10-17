import AppKit
import WebKit

/// View mode: a WKWebView showing the rendered document.
///
/// Markdown is rendered by a bundled page (web/markdown.html) served at the file's own path over
/// `tabbit-file:` (see LocalFileSchemeHandler), so relative images and links resolve against the
/// file's folder. The page stays loaded; new text is passed to `window.tabbit.render`, which keeps
/// the scroll position.
final class PreviewController: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private let document: TabbitDocument
    private let schemeHandler = LocalFileSchemeHandler(pageHTML: PreviewController.markdownPage)

    /// The text currently shown (or about to be shown once the page finishes loading).
    private var text = ""
    /// The file the Markdown page was loaded for, and whether it is ready for render calls.
    private var markdownFileURL: URL?
    private var markdownPageReady = false

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
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        webView.isInspectable = true
        // Invisible until the first content is in, to avoid a white flash in dark mode.
        webView.alphaValue = 0
    }

    func show(_ text: String) {
        self.text = text
        switch document.kind {
        case .markdown: showMarkdown()
        case .html: showHTML()
        }
    }

    // MARK: Markdown

    private func showMarkdown() {
        guard let fileURL = document.fileURL else { return }
        if fileURL != markdownFileURL {
            // First show, or the file moved (Save As, rename): (re)load the page; didFinish renders.
            guard let pageURL = LocalFileSchemeHandler.schemeURL(for: fileURL) else { return }
            markdownFileURL = fileURL
            markdownPageReady = false
            schemeHandler.documentURL = fileURL
            webView.load(URLRequest(url: pageURL))
        } else if markdownPageReady {
            renderMarkdown()
        }
    }

    private func renderMarkdown() {
        webView.callAsyncJavaScript("window.tabbit.render(text)", arguments: ["text": text],
                                    in: nil, in: .page) { [weak self] result in
            if case .failure(let error) = result {
                NSLog("Tabbit: Markdown render failed: \(error)")
            }
            self?.webView.alphaValue = 1
        }
    }

    // MARK: HTML

    private func showHTML() {
        guard let fileURL = document.fileURL else { return }
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        switch document.kind {
        case .markdown:
            // Also covers a reload from the context menu, which brings back the empty page.
            markdownPageReady = true
            renderMarkdown()
        case .html:
            webView.alphaValue = 1
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.alphaValue = 1
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.alphaValue = 1
    }
}
