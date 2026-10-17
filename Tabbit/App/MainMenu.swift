import AppKit

/// Builds the main menu in code (the app has no nib or storyboard).
enum MainMenu {
    static func make() -> NSMenu {
        let mainMenu = NSMenu()
        for submenu in [appMenu(), fileMenu(), editMenu(), viewMenu(), windowMenu(), helpMenu()] {
            let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        return mainMenu
    }

    private static func appMenu() -> NSMenu {
        let name = ProcessInfo.processInfo.processName
        let menu = NSMenu(title: name)
        menu.addItem(withTitle: "About \(name)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())

        let services = NSMenu(title: "Services")
        menu.addItem(withTitle: "Services", action: nil, keyEquivalent: "").submenu = services
        NSApp.servicesMenu = services
        menu.addItem(.separator())

        menu.addItem(withTitle: "Hide \(name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        // AppKit inserts and maintains File > Open Recent after Open… by itself.
        menu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: "Save", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        menu.addItem(withTitle: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        menu.addItem(withTitle: "Revert to Saved", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Reveal in Finder", action: #selector(DocumentWindowController.revealInFinder(_:)), keyEquivalent: "r")
            .keyEquivalentModifierMask = [.command, .option]
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(withTitle: "Edit Mode", action: #selector(DocumentWindowController.toggleEditMode(_:)), keyEquivalent: "e")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show Toolbar", action: #selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent: "t")
            .keyEquivalentModifierMask = [.command, .option]
        // Same shortcut as Finder's View > Show Path Bar.
        menu.addItem(withTitle: "Show File Path", action: #selector(AppDelegate.toggleFilePath(_:)), keyEquivalent: "p")
            .keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
            .keyEquivalentModifierMask = [.command, .control]
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        // AppKit adds the tab commands and the window list to the registered Window menu.
        NSApp.windowsMenu = menu
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        NSApp.helpMenu = menu
        return menu
    }
}
