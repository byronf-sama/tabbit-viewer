import AppKit

enum DocumentMode {
    case view
    case edit
}

/// Content of a document tab: the rendered view and the source editor, one visible at a time.
final class DocumentViewController: NSViewController {
    let document: TabbitDocument
    private(set) var mode: DocumentMode = .view
    var modeDidChange: ((DocumentMode) -> Void)?

    private lazy var preview = PreviewController(document: document)
    /// Created the first time the tab switches to Edit.
    private var editor: EditorController?

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
        mode == .edit ? (editor?.webView ?? view) : preview.webView
    }

    func setMode(_ newMode: DocumentMode) {
        guard newMode != mode else { return }
        mode = newMode
        modeDidChange?(mode)
        switch mode {
        case .edit:
            let editor = editor ?? makeEditor()
            editor.webView.isHidden = false
            preview.webView.isHidden = true
            editor.focus()
        case .view:
            // Show the current edits, saved or not.
            syncTextFromEditor { [self] in
                preview.show(document.text, isSaved: document.text == document.savedText)
                guard mode == .view else { return }
                editor?.webView.isHidden = true
                preview.webView.isHidden = false
                view.window?.makeFirstResponder(preview.webView)
            }
        }
    }

    /// Copies the editor's text (if there is an editor) into the document.
    func syncTextFromEditor(_ completion: @escaping () -> Void) {
        guard let editor else { return completion() }
        editor.fetchText { [self] text in
            if let text { document.updateText(text) }
            completion()
        }
    }

    func documentDidSave(_ text: String) {
        editor?.markSaved(text)
    }

    /// The document was (re)read from disk, e.g. File > Revert to Saved.
    func documentTextDidLoad() {
        editor?.load(document.text)
        preview.show(document.text, isSaved: true)
    }

    private func makeEditor() -> EditorController {
        let editor = EditorController(document: document)
        editor.dirtyDidChange = { [weak self] dirty in
            self?.document.updateChangeCount(dirty ? .changeDone : .changeCleared)
        }
        embed(editor.webView)
        self.editor = editor
        return editor
    }

    private func embed(_ subview: NSView) {
        subview.frame = view.bounds
        subview.autoresizingMask = [.width, .height]
        view.addSubview(subview)
    }
}
