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

    /// Holds the preview and editor web views; the path bar sits below it.
    private let webContainer = NSView()
    private let pathBar = PathBar()

    init(document: TabbitDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 980, height: 760))
        // A hidden arranged view is taken out of the layout, so the web views fill the tab
        // when the path bar is off.
        let stack = NSStackView(views: [webContainer, pathBar])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        webContainer.setContentHuggingPriority(.defaultLow, for: .vertical)
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            pathBar.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        view = root
        embed(preview.webView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preview.show(document.text, isSaved: true)
        updatePathBar()
        NotificationCenter.default.addObserver(self, selector: #selector(updatePathBar),
                                               name: AppSettings.showFilePathDidChange, object: nil)
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

    func documentLocationDidChange() {
        updatePathBar()
    }

    @objc private func updatePathBar() {
        pathBar.path = document.fileURL?.path(percentEncoded: false) ?? ""
        pathBar.isHidden = !AppSettings.showFilePath
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
        subview.frame = webContainer.bounds
        subview.autoresizingMask = [.width, .height]
        webContainer.addSubview(subview)
    }
}
