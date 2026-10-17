import AppKit

// The first NSDocumentController instance becomes NSDocumentController.shared,
// so create the subclass before AppKit creates the default one.
_ = TabbitDocumentController()

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
