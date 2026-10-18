import AppKit
import ApplicationServices

/// Reveal in Finder that reuses Finder tabs, where NSWorkspace would open a new window:
/// - a Finder tab (in any window) already shows the file's folder: switch to it;
/// - otherwise, open the folder in a new tab of the frontmost Finder window;
/// - no Finder window open: Finder opens one.
/// In each case the file is selected and scrolled into view (Finder's `reveal`).
///
/// Telling Finder what to do needs the user's one-time Automation consent ("Tabbit wants to
/// control Finder", explained by NSAppleEventsUsageDescription in Info.plist). Finder can't
/// script tabs, so opening one presses its File > New Tab, which needs Accessibility access.
/// Without either, this falls back to NSWorkspace (a new window); it never changes the folder
/// shown in an existing tab.
enum FinderReveal {
    private static var askedForAccessibility = false

    static func reveal(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Shows the consent prompt the first time; that blocks this thread, not the UI.
            let finder = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
            let status = AEDeterminePermissionToAutomateTarget(finder.aeDesc, typeWildCard, typeWildCard, true)
            DispatchQueue.main.async {
                if status == noErr, revealInFinderTab(url) { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    /// Returns false if the file wasn't revealed, so the caller can fall back to NSWorkspace.
    @MainActor
    private static func revealInFinderTab(_ url: URL) -> Bool {
        let paths = """
            set theFile to POSIX file \(appleScriptString(url.path(percentEncoded: false))) as alias
            set theFolder to POSIX file \(appleScriptString(url.deletingLastPathComponent().path(percentEncoded: false))) as alias
            """
        NSApp.yieldActivation(toApplicationWithBundleIdentifier: "com.apple.finder")
        // Finder lists each tab as a Finder window, frontmost first. Returns "revealed", or the
        // number of Finder windows when the folder needs a new tab.
        guard let result = run("""
            \(paths)
            tell application "Finder"
                activate
                set openWindows to every Finder window whose collapsed is false
                if openWindows is {} then
                    reveal theFile
                    return "revealed"
                end if
                repeat with i from 1 to count openWindows
                    set w to item i of openWindows
                    try
                        if (target of w as alias as text) is (theFolder as text) then
                            set index of w to 1
                            reveal theFile
                            return "revealed"
                        end if
                    end try
                end repeat
                set index of item 1 of openWindows to 1
                return (count Finder windows) as text
            end tell
            """) else { return false }
        if result == "revealed" { return true }

        guard let windowCount = Int(result), hasAccessibilityAccess(), pressNewTab() else { return false }
        // The tab may appear a moment after the press; wait for it before retargeting window 1,
        // or the existing tab would be changed instead.
        return run("""
            \(paths)
            tell application "Finder"
                repeat 40 times
                    if (count Finder windows) > \(windowCount) then exit repeat
                    delay 0.025
                end repeat
                if (count Finder windows) is \(windowCount) then error "Finder didn't open a tab"
                set target of Finder window 1 to theFolder
                reveal theFile
            end tell
            """) != nil
    }

    /// Asks for Accessibility access (the system prompt sends the user to System Settings) at
    /// most once per launch.
    @MainActor
    private static func hasAccessibilityAccess() -> Bool {
        if AXIsProcessTrusted() { return true }
        if !askedForAccessibility {
            askedForAccessibility = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return false
    }

    /// Presses File > New Tab in Finder's menu bar. The item is found by its shortcut (⌘T),
    /// because its title depends on the system language.
    private static func pressNewTab() -> Bool {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        else { return false }
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 2)
        guard let menuBar = attribute(app, kAXMenuBarAttribute) else { return false }
        let menuItems = children(menuBar as! AXUIElement).lazy.flatMap(children).flatMap(children)
        guard let newTab = menuItems.first(where: { item in
            attribute(item, kAXMenuItemCmdCharAttribute) as? String == "T"
                && attribute(item, kAXMenuItemCmdModifiersAttribute) as? Int == 0 // ⌘ only
                && attribute(item, kAXEnabledAttribute) as? Bool == true
        }) else { return false }
        return AXUIElementPerformAction(newTab, kAXPressAction as CFString) == .success
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    /// Runs AppleScript and returns its result as text, or nil (logged) if it failed.
    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("Tabbit: Reveal in Finder via AppleScript failed: \(error)") }
        return error == nil ? result?.stringValue ?? "" : nil
    }

    /// A quoted AppleScript string literal.
    private static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
