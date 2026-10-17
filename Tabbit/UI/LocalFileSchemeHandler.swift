import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves the Markdown viewer over a private URL scheme that mirrors file paths:
/// `tabbit-file:///path/to/notes.md` returns the viewer page, and any other
/// `tabbit-file:///path/...` inside the document's folder returns that file from disk.
///
/// This way relative images and links resolve against the file's folder, `#anchor` links stay
/// same-document, and Swift does all file reading (limited to the document's folder).
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "tabbit-file"

    /// The Markdown file being shown, and the page to serve at its URL.
    var documentURL: URL?
    let pageHTML: String

    private var activeTasks = Set<ObjectIdentifier>()

    init(pageHTML: String) {
        self.pageHTML = pageHTML
    }

    static func schemeURL(for fileURL: URL) -> URL? {
        // A file URL's absoluteString is already percent-encoded: swap "file:" for our scheme.
        let absolute = fileURL.standardizedFileURL.absoluteString
        guard absolute.hasPrefix("file:") else { return nil }
        return URL(string: scheme + absolute.dropFirst("file".count))
    }

    static func fileURL(for schemeURL: URL) -> URL? {
        guard schemeURL.scheme == scheme else { return nil }
        let path = schemeURL.path(percentEncoded: false)
        return path.isEmpty ? nil : URL(filePath: path).standardizedFileURL
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let requestURL = task.request.url, let fileURL = Self.fileURL(for: requestURL),
              let documentURL = documentURL?.standardizedFileURL else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        if fileURL == documentURL {
            respond(to: task, url: requestURL, data: Data(pageHTML.utf8), mimeType: "text/html")
            return
        }
        var folderPath = documentURL.deletingLastPathComponent().path(percentEncoded: false)
        if !folderPath.hasSuffix("/") { folderPath += "/" }
        guard fileURL.path(percentEncoded: false).hasPrefix(folderPath) else {
            task.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }

        let id = ObjectIdentifier(task)
        activeTasks.insert(id)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Data(contentsOf: fileURL) }
            DispatchQueue.main.async { [self] in
                // The task may have been stopped (page reloaded or closed) while reading.
                guard activeTasks.remove(id) != nil else { return }
                switch result {
                case .success(let data):
                    let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                    respond(to: task, url: requestURL, data: data, mimeType: mimeType ?? "application/octet-stream")
                case .failure:
                    task.didFailWithError(URLError(.fileDoesNotExist))
                }
            }
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        activeTasks.remove(ObjectIdentifier(task))
    }

    private func respond(to task: WKURLSchemeTask, url: URL, data: Data, mimeType: String) {
        let encoding = mimeType.hasPrefix("text/") || mimeType == "image/svg+xml" ? "utf-8" : nil
        task.didReceive(URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count,
                                    textEncodingName: encoding))
        task.didReceive(data)
        task.didFinish()
    }
}
