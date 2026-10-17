import AppKit

/// Adds "Reveal in Finder" to the menu you get by right-clicking a window tab.
///
/// AppKit builds that menu itself and has no API to extend it. Its items (Close Tab, Move Tab to
/// New Window, ...) target the clicked tab's window, so when such a menu starts tracking, append
/// an item for that window's document.
enum TabContextMenu {
    private static let revealItemID = NSUserInterfaceItemIdentifier("io.github.byronf-sama.tabbit.revealInFinder")

    static func install() {
        NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification,
                                               object: nil, queue: .main) { notification in
            guard let menu = notification.object as? NSMenu else { return }
            MainActor.assumeIsolated { extend(menu) }
        }
    }

    @MainActor
    private static func extend(_ menu: NSMenu) {
        guard let tabItem = menu.items.first(where: { $0.action == #selector(NSWindow.moveTabToNewWindow(_:)) }),
              let controller = (tabItem.target as? NSWindow)?.windowController as? DocumentWindowController,
              !menu.items.contains(where: { $0.identifier == revealItemID }) else { return }

        let reveal = NSMenuItem(title: "Reveal in Finder",
                                action: #selector(DocumentWindowController.revealInFinder(_:)), keyEquivalent: "")
        reveal.identifier = revealItemID
        reveal.target = controller
        reveal.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(.separator())
        menu.addItem(reveal)
    }
}
