import Foundation

/// User-facing settings, kept in UserDefaults.
enum AppSettings {
    static let showFilePathDidChange = Notification.Name("io.github.byronf-sama.tabbit.showFilePathDidChange")
    private static let showFilePathKey = "ShowFilePath"

    /// View > Show File Path: a bar with the file's absolute path at the bottom of every tab.
    static var showFilePath: Bool {
        get { UserDefaults.standard.bool(forKey: showFilePathKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: showFilePathKey)
            NotificationCenter.default.post(name: showFilePathDidChange, object: nil)
        }
    }
}
