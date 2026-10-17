import AppKit
import UniformTypeIdentifiers

/// One document class for both Markdown and HTML files. Swift owns all file I/O;
/// the web views only ever receive and return text.
final class TabbitDocument: NSDocument {
    enum Kind {
        case markdown
        case html
    }

    /// The document's text as of the last load (or the last sync from the editor).
    private(set) var text = ""
    private var encoding: String.Encoding = .utf8
    private var hasUTF8BOM = false

    /// Classic document behavior: an edited dot on unsaved tabs and a prompt when closing them.
    override class var autosavesInPlace: Bool { false }

    var kind: Kind {
        if let fileType, let type = UTType(fileType), type.conforms(to: .html) { return .html }
        if let ext = fileURL?.pathExtension.lowercased(), ext == "html" || ext == "htm" { return .html }
        return .markdown
    }

    private var documentWindowControllers: [DocumentWindowController] {
        windowControllers.compactMap { $0 as? DocumentWindowController }
    }

    override func makeWindowControllers() {
        addWindowController(DocumentWindowController(document: self))
    }

    override func showWindows() {
        documentWindowControllers.forEach { $0.joinFrontmostTabGroup() }
        super.showWindows()
    }

    // MARK: Reading and writing

    override func read(from data: Data, ofType typeName: String) throws {
        var data = data
        hasUTF8BOM = data.starts(with: [0xEF, 0xBB, 0xBF])
        if hasUTF8BOM { data = data.dropFirst(3) }
        (text, encoding) = Self.decode(data)
        // Non-empty only on File > Revert; a fresh document has no windows yet.
        documentWindowControllers.forEach { $0.documentTextDidLoad() }
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let body = text.data(using: encoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return hasUTF8BOM ? Data([0xEF, 0xBB, 0xBF]) + body : body
    }

    /// UTF-8 when valid, otherwise whatever encoding Foundation detects (remembered for saving).
    private static func decode(_ data: Data) -> (String, String.Encoding) {
        if let string = String(data: data, encoding: .utf8) {
            return (string, .utf8)
        }
        var converted: NSString?
        var usedLossy: ObjCBool = false
        let raw = NSString.stringEncoding(for: data, encodingOptions: [.allowLossyKey: false],
                                          convertedString: &converted, usedLossyConversion: &usedLossy)
        if raw != 0, let converted {
            return (converted as String, String.Encoding(rawValue: raw))
        }
        return (String(decoding: data, as: UTF8.self), .utf8)
    }
}
