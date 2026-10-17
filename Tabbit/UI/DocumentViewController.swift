import AppKit

enum DocumentMode {
    case view
    case edit
}

/// Content of a document tab: the rendered view, and the source editor.
final class DocumentViewController: NSViewController {
    let document: TabbitDocument
    private(set) var mode: DocumentMode = .view
    var modeDidChange: ((DocumentMode) -> Void)?

    private lazy var preview = PreviewController(document: document)
    /// Placeholder for the source editor until Milestone 4.
    private var editorView: NSScrollView?

    init(document: TabbitDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 980, height: 760))
        embed(preview.webView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preview.show(document.text, isSaved: true)
    }

    /// The view that should get keyboard focus for the current mode.
    var focusView: NSView {
        mode == .edit ? (editorView?.documentView ?? view) : preview.webView
    }

    func setMode(_ newMode: DocumentMode) {
        guard newMode != mode else { return }
        mode = newMode
        switch mode {
        case .view:
            editorView?.isHidden = true
            preview.webView.isHidden = false
        case .edit:
            let editor = editorView ?? makeEditorPlaceholder()
            editor.isHidden = false
            preview.webView.isHidden = true
        }
        view.window?.makeFirstResponder(focusView)
        modeDidChange?(mode)
    }

    func documentTextDidLoad() {
        (editorView?.documentView as? NSTextView)?.string = document.text
        preview.show(document.text, isSaved: true)
    }

    private func embed(_ subview: NSView) {
        subview.frame = view.bounds
        subview.autoresizingMask = [.width, .height]
        view.addSubview(subview)
    }

    private func makeEditorPlaceholder() -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.string = document.text
        embed(scrollView)
        editorView = scrollView
        return scrollView
    }
}
