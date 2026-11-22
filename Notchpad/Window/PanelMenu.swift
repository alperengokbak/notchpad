import AppKit

/// Right-click menu on the open panel.
@MainActor
enum PanelMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
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

    @objc func toggleLogin() {
        try? LoginItem.setEnabled(!LoginItem.isEnabled)
    }
}
