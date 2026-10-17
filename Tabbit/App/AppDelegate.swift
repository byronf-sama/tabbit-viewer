import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // The editor is a web view: keep WebKit's text substitutions (which follow the system
        // "smart quotes and dashes" setting) and autocorrect out of source code.
        UserDefaults.standard.register(defaults: [
            "WebAutomaticQuoteSubstitutionEnabled": false,
            "WebAutomaticDashSubstitutionEnabled": false,
            "WebAutomaticTextReplacementEnabled": false,
            "WebAutomaticSpellingCorrectionEnabled": false,
            "WebContinuousSpellCheckingEnabled": false,
            "WebAutomaticLinkDetectionEnabled": false,
        ])
        NSApp.mainMenu = MainMenu.make()
        TabContextMenu.install()
    }

    /// Tabbit has no untitled documents. AppKit calls this at launch when no file was opened
    /// or restored, and when the Dock icon is clicked with no windows open: show the Open panel.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        NSDocumentController.shared.openDocument(nil)
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: View > Show/Hide File Path (applies to all tabs)

    @IBAction func toggleFilePath(_ sender: Any?) {
        AppSettings.showFilePath.toggle()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleFilePath(_:)) {
            menuItem.title = AppSettings.showFilePath ? "Hide File Path" : "Show File Path"
        }
        return true
    }
}
