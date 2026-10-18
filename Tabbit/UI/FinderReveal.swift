import AppKit

/// Reveal in Finder that reuses the frontmost Finder window: it moves that window to the file's
/// folder and selects the file, where NSWorkspace would open a new window. With no Finder window
/// open, Finder opens one.
///
/// Telling Finder what to do needs the user's one-time Automation consent ("Tabbit wants to
/// control Finder", explained by NSAppleEventsUsageDescription in Info.plist). Without it, this
/// falls back to NSWorkspace.
enum FinderReveal {
    static func reveal(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Shows the consent prompt the first time; that blocks this thread, not the UI.
            let finder = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
            let status = AEDeterminePermissionToAutomateTarget(finder.aeDesc, typeWildCard, typeWildCard, true)
            DispatchQueue.main.async {
                if status == noErr, revealInFrontWindow(url) { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private static func revealInFrontWindow(_ url: URL) -> Bool {
        let file = appleScriptString(url.path(percentEncoded: false))
        let folder = appleScriptString(url.deletingLastPathComponent().path(percentEncoded: false))
        let source = """
            set theFile to POSIX file \(file) as alias
            set theFolder to POSIX file \(folder) as alias
            tell application "Finder"
                set openWindows to every Finder window whose collapsed is false
                if openWindows is {} then
                    reveal theFile
                else
                    set frontWindow to item 1 of openWindows
                    set target of frontWindow to theFolder
                    set index of frontWindow to 1
                    select theFile
                end if
                activate
            end tell
            """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("Tabbit: Reveal in Finder via AppleScript failed: \(error)") }
        return error == nil
    }

    /// A quoted AppleScript string literal.
    private static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
