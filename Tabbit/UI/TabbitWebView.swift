import WebKit

/// A WKWebView that leaves Control-Tab and Control-Shift-Tab (Show Next/Previous Tab) to the
/// menu. Otherwise the page gets them first and treats them as Tab, so switching tabs from the
/// keyboard would not work while a web view has focus.
final class TabbitWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 48, event.modifierFlags.contains(.control),
           NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
