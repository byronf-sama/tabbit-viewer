import AppKit

enum DocumentMode {
    case view
    case edit
}

/// Content of a document tab. Milestone 1 placeholder: shows the raw text and the current mode.
final class DocumentViewController: NSViewController {
    let document: TabbitDocument
    private(set) var mode: DocumentMode = .view
    var modeDidChange: ((DocumentMode) -> Void)?

    private let modeLabel = NSTextField(labelWithString: "")
    private weak var textView: NSTextView?

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

        modeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        modeLabel.textColor = .secondaryLabelColor
        modeLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSTextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)

        root.addSubview(modeLabel)
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            modeLabel.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor, constant: 8),
            modeLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.topAnchor.constraint(equalTo: modeLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
        textView.string = document.text
        self.textView = textView
        updateModeLabel()
    }

    func setMode(_ newMode: DocumentMode) {
        guard newMode != mode else { return }
        mode = newMode
        updateModeLabel()
        modeDidChange?(mode)
    }

    func documentTextDidLoad() {
        textView?.string = document.text
    }

    private func updateModeLabel() {
        let kind = document.kind == .markdown ? "Markdown" : "HTML"
        modeLabel.stringValue = "\(kind) · \(mode == .view ? "View" : "Edit") mode (placeholder)"
    }
}
