import WebKit

/// A WKWebView that leaves Control-Tab and Control-Shift-Tab (Show Next/Previous Tab) to the
/// menu. Otherwise the page gets them first and treats them as Tab, so switching tabs from the
/// keyboard would not work while a web view has focus.
/// Find shortcuts also go through the menu so they reach the selected mode during transitions.
final class TabbitWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let findShortcut = (modifiers == [.command] || modifiers == [.command, .shift])
            && ["f", "g"].contains(event.charactersIgnoringModifiers?.lowercased() ?? "")
        let tabShortcut = event.keyCode == 48 && event.modifierFlags.contains(.control)
        if findShortcut || tabShortcut,
           NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
