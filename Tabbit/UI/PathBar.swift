import AppKit

/// The bar at the bottom of a tab that shows the document's absolute path (View > Show File Path).
/// The path is selectable, so it can be copied.
final class PathBar: NSView {
    private let label = NSTextField(labelWithString: "")

    var path = "" {
        didSet {
            label.stringValue = path
            label.toolTip = path
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        let separator = NSBox()
        separator.boxType = .separator

        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingMiddle
        label.usesSingleLineMode = true
        label.isSelectable = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for view in [separator, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 24),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        // Resolved for the current (light/dark) appearance each time it changes.
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
}
