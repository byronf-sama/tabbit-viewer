import AppKit

private extension NSToolbarItem.Identifier {
    static let mode = NSToolbarItem.Identifier("io.github.byronf-sama.tabbit.mode")
}

/// One window per document. Windows are native tabs: every newly opened document joins
/// the frontmost Tabbit window, regardless of the system "Prefer tabs" setting.
final class DocumentWindowController: NSWindowController, NSToolbarDelegate, NSMenuItemValidation {
    private static let frameName = "TabbitDocumentWindow"

    private let content: DocumentViewController
    private let modeControl = NSSegmentedControl(labels: ["View", "Edit"], trackingMode: .selectOne,
                                                 target: nil, action: nil)

    init(document: TabbitDocument) {
        content = DocumentViewController(document: document)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: true)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "io.github.byronf-sama.tabbit.document"
        window.contentViewController = content
        window.initialFirstResponder = content.focusView
        window.setContentSize(NSSize(width: 980, height: 760))
        window.minSize = NSSize(width: 420, height: 300)
        window.center()
        // Only one window can own the autosave name; the others just start from the saved frame.
        if !window.setFrameAutosaveName(Self.frameName) {
            window.setFrameUsingName(Self.frameName)
        }

        super.init(window: window)

        modeControl.target = self
        modeControl.action = #selector(modeControlChanged(_:))
        modeControl.setToolTip("View rendered output", forSegment: 0)
        modeControl.setToolTip("Edit source (⌘E toggles)", forSegment: 1)
        modeControl.selectedSegment = 0
        content.modeDidChange = { [weak self] mode in
            self?.modeControl.selectedSegment = mode == .edit ? 1 : 0
        }

        let toolbar = NSToolbar(identifier: "TabbitDocumentToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Puts a not-yet-shown window into the frontmost Tabbit window's tab group (as the last tab).
    func joinFrontmostTabGroup() {
        guard let window, !window.isVisible, !window.isMiniaturized, window.tabbedWindows == nil else { return }
        let host = NSApp.orderedWindows.first { other in
            other !== window && other.windowController is DocumentWindowController
                && other.isVisible && !other.isMiniaturized
        }
        guard let host else { return }
        if let group = host.tabGroup {
            group.addWindow(window)
        } else {
            host.addTabbedWindow(window, ordered: .above)
        }
    }

    func documentTextDidLoad() {
        content.documentTextDidLoad()
    }

    // MARK: Mode switching

    @objc private func modeControlChanged(_ sender: NSSegmentedControl) {
        content.setMode(sender.selectedSegment == 1 ? .edit : .view)
    }

    @IBAction func toggleEditMode(_ sender: Any?) {
        content.setMode(content.mode == .edit ? .view : .edit)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleEditMode(_:)) {
            menuItem.state = content.mode == .edit ? .on : .off
        }
        return true
    }

    // MARK: NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .mode]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, .mode]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier == .mode else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Mode"
        item.paletteLabel = "View / Edit"
        item.view = modeControl
        return item
    }
}
