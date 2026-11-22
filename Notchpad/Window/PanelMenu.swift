import AppKit
import NotchpadCore

/// Right-click menu on the open panel.
@MainActor
enum PanelMenu {
    static func make(shelf: ShelfStore?) -> NSMenu {
        let menu = NSMenu()
        if let shelf, !shelf.items.isEmpty {
            let clear = NSMenuItem(title: "Clear shelf", action: #selector(MenuTarget.clearShelf), keyEquivalent: "")
            clear.target = MenuTarget.shared
            MenuTarget.shared.shelf = shelf
            menu.addItem(clear)
            menu.addItem(.separator())
        }
        let login = NSMenuItem(title: "Launch at login", action: #selector(MenuTarget.toggleLogin), keyEquivalent: "")
        login.target = MenuTarget.shared
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Notchpad", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }
}

@MainActor
final class MenuTarget: NSObject {
    static let shared = MenuTarget()
    weak var shelf: ShelfStore?

    @objc func clearShelf() {
        shelf?.clear()
    }

    @objc func toggleLogin() {
        try? LoginItem.setEnabled(!LoginItem.isEnabled)
    }
}
