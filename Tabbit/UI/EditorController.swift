import AppKit
import WebKit

/// Edit mode: the bundled CodeMirror page (web/editor.html) in a WKWebView.
///
/// Swift stays the owner of the text: it loads text into the editor, asks for it back when
/// saving or switching to View, and tells the editor when it was saved. The page reports
/// whether its text differs from the saved text, which drives the document's edited state.
final class EditorController: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let webView: WKWebView
    private let document: TabbitDocument
    private let pageURL = Bundle.main.url(forResource: "editor", withExtension: "html", subdirectory: "web")

    private var isReady = false
    /// Text to load once the page has reported "ready".
    private var pendingText: String?
    /// Focus was requested before the editor had content.
    private var pendingFocus = false

    /// Called when the text starts or stops differing from the saved file.
    var dirtyDidChange: ((Bool) -> Void)?

    init(document: TabbitDocument) {
        self.document = document
        let configuration = WKWebViewConfiguration()
        webView = TabbitWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(WeakScriptMessageHandler(self), name: "tabbit")
        webView.navigationDelegate = self
        webView.isInspectable = true
        webView.alphaValue = 0
        load(document.text)
        if let pageURL {
            webView.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
        }
    }

    /// Replaces the editor's content, resetting undo history; `text` counts as saved.
    func load(_ text: String) {
        guard isReady else {
            pendingText = text
            return
        }
        let language = document.kind == .markdown ? "markdown" : "html"
        webView.callAsyncJavaScript("window.tabbit.setDocument(text, language)",
                                    arguments: ["text": text, "language": language],
                                    in: nil, in: .page) { [weak self] _ in
            guard let self else { return }
            webView.alphaValue = 1
            if pendingFocus { focus() }
        }
    }

    /// The editor's current text (nil if it could not be read).
    func fetchText(_ completion: @escaping (String?) -> Void) {
        guard isReady, pendingText == nil else {
            completion(pendingText)
            return
        }
        webView.callAsyncJavaScript("return window.tabbit.getText()", arguments: [:],
                                    in: nil, in: .page) { result in
            completion((try? result.get()) as? String)
        }
    }

    /// `text` was written to disk.
    func markSaved(_ text: String) {
        guard isReady else { return }
        webView.callAsyncJavaScript("window.tabbit.markSaved(text)", arguments: ["text": text],
                                    in: nil, in: .page, completionHandler: nil)
    }

    func focus() {
        webView.window?.makeFirstResponder(webView)
        pendingFocus = !isReady || pendingText != nil
        if !pendingFocus {
            webView.evaluateJavaScript("window.tabbit.focus()")
        }
    }

    // MARK: WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            isReady = true
            if let text = pendingText {
                pendingText = nil
                load(text)
            }
        case "dirty":
            dirtyDidChange?(body["dirty"] as? Bool ?? false)
        default:
            break
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        if url == pageURL { return decisionHandler(.allow) }
        // Anything else (e.g. a file dropped on the editor) goes where a link would.
        decisionHandler(.cancel)
        LinkRouter.open(url)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // The page is gone: reload it with the last text Swift knows about.
        isReady = false
        pendingText = document.text
        if let pageURL {
            webView.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
        }
    }
}

/// WKUserContentController retains its handlers; this breaks the cycle back to the controller.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
