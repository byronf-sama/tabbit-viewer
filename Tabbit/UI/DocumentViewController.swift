import AppKit

enum DocumentMode {
    case view
    case edit
}

/// Content of a document tab: the rendered view and the source editor, one visible at a time.
final class DocumentViewController: NSViewController, NSSearchFieldDelegate {
    let document: TabbitDocument
    private(set) var mode: DocumentMode = .view
    var modeDidChange: ((DocumentMode) -> Void)?

    private lazy var preview = PreviewController(document: document)
    /// Created the first time the tab switches to Edit.
    private var editor: EditorController?

    /// Holds the preview and editor web views; the path bar sits below it.
    private let webContainer = NSView()
    private let pathBar = PathBar()
    private let findBarHost = NSStackView()
    private let findField = NSSearchField()
    private let findStatus = NSTextField(labelWithString: "")
    private var findRequest = 0

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
        configureFindBar()
        findBarHost.isHidden = true
        let stack = NSStackView(views: [findBarHost, webContainer, pathBar])
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
            findBarHost.widthAnchor.constraint(equalTo: stack.widthAnchor),
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
            hideFindBar(nil)
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
                view.window?.makeFirstResponder(findBarHost.isHidden ? preview.webView : findField)
            }
        }
    }

    func find(_ action: NSTextFinder.Action) {
        if mode == .view {
            switch action {
            case .showFindInterface:
                findBarHost.isHidden = false
                view.window?.makeFirstResponder(findField)
                findField.selectText(nil)
            case .nextMatch: searchPreview()
            case .previousMatch: searchPreview(backwards: true)
            default: break
            }
        } else {
            editor?.find(action)
        }
    }

    func canFind(_ action: NSTextFinder.Action) -> Bool {
        mode == .view || editor != nil
    }

    private func configureFindBar() {
        findField.placeholderString = "Find in document"
        findField.setAccessibilityLabel("Find in document")
        findField.delegate = self
        findField.target = self
        findField.action = #selector(findNext(_:))
        findField.sendsWholeSearchString = true
        findField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        findStatus.textColor = .secondaryLabelColor
        findStatus.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let previous = NSButton(title: "↑", target: self, action: #selector(findPrevious(_:)))
        previous.toolTip = "Previous match (⇧⌘G)"
        previous.setAccessibilityLabel("Previous match")
        let next = NSButton(title: "↓", target: self, action: #selector(findNext(_:)))
        next.toolTip = "Next match (⌘G)"
        next.setAccessibilityLabel("Next match")
        let done = NSButton(title: "Done", target: self, action: #selector(hideFindBar(_:)))
        for control in [findField, findStatus, previous, next, done] {
            findBarHost.addArrangedSubview(control)
        }
        findBarHost.orientation = .horizontal
        findBarHost.spacing = 8
        findBarHost.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    }

    func controlTextDidChange(_ notification: Notification) {
        searchPreview()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            hideFindBar(nil)
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            searchPreview(backwards: NSApp.currentEvent?.modifierFlags.contains(.shift) == true)
            return true
        }
        return false
    }

    @objc private func findNext(_ sender: Any?) { searchPreview() }
    @objc private func findPrevious(_ sender: Any?) { searchPreview(backwards: true) }

    @objc private func hideFindBar(_ sender: Any?) {
        findRequest += 1
        findBarHost.isHidden = true
        findStatus.stringValue = ""
        preview.find("") { _ in }
        view.window?.makeFirstResponder(preview.webView)
    }

    private func searchPreview(backwards: Bool = false) {
        guard mode == .view else { return }
        if findBarHost.isHidden { find(.showFindInterface) }
        let query = findField.stringValue
        findRequest += 1
        let request = findRequest
        preview.find(query, backwards: backwards) { [weak self] found in
            guard let self, request == findRequest else { return }
            findStatus.stringValue = query.isEmpty || found ? "" : "No matches"
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
