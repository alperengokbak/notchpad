import AppKit
import NotchpadCore

/// Right-click menu on the open panel.
@MainActor
enum PanelMenu {
    static func make(shelf: ShelfStore?, editing: Bool, onEditWidgets: @escaping () -> Void,
                     micShown: Bool, onToggleMic: @escaping () -> Void,
                     closedMusicShown: Bool, onToggleClosedMusic: @escaping () -> Void,
                     hasBackground: Bool = false, onChooseBackground: @escaping () -> Void = {},
                     onRemoveBackground: @escaping () -> Void = {},
                     toggles: [MenuToggle] = []) -> NSMenu {
        let menu = NSMenu()
        let edit = NSMenuItem(title: editing ? "Done editing" : "Edit widgets…",
                              action: #selector(MenuTarget.editWidgets), keyEquivalent: "")
        edit.target = MenuTarget.shared
        MenuTarget.shared.onEditWidgets = onEditWidgets
        menu.addItem(edit)
        menu.addItem(.separator())
        if let shelf, !shelf.items.isEmpty {
            let clear = NSMenuItem(title: "Clear shelf", action: #selector(MenuTarget.clearShelf), keyEquivalent: "")
            clear.target = MenuTarget.shared
            MenuTarget.shared.shelf = shelf
            menu.addItem(clear)
            let airdrop = NSMenuItem(title: "AirDrop all files", action: #selector(MenuTarget.airdropAll), keyEquivalent: "")
            airdrop.target = MenuTarget.shared
            menu.addItem(airdrop)
            menu.addItem(.separator())
        }
        if AppModel.micIndicatorAvailable {
            let mic = NSMenuItem(title: "Show microphone indicator", action: #selector(MenuTarget.toggleMic), keyEquivalent: "")
            mic.target = MenuTarget.shared
            mic.state = micShown ? .on : .off
            MenuTarget.shared.onToggleMic = onToggleMic
            menu.addItem(mic)
        }
        let music = NSMenuItem(title: "Show music on closed notch", action: #selector(MenuTarget.toggleClosedMusic), keyEquivalent: "")
        music.target = MenuTarget.shared
        music.state = closedMusicShown ? .on : .off
        MenuTarget.shared.onToggleClosedMusic = onToggleClosedMusic
        menu.addItem(music)
        for t in toggles {
            let item = ClosureMenuItem(t.title, t.action)
            item.state = t.isOn == true ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let chooseBG = NSMenuItem(title: hasBackground ? "Change background image…" : "Choose background image…",
                                  action: #selector(MenuTarget.chooseBackground), keyEquivalent: "")
        chooseBG.target = MenuTarget.shared
        MenuTarget.shared.onChooseBackground = onChooseBackground
        menu.addItem(chooseBG)
        if hasBackground {
            let removeBG = NSMenuItem(title: "Remove background image", action: #selector(MenuTarget.removeBackground), keyEquivalent: "")
            removeBG.target = MenuTarget.shared
            MenuTarget.shared.onRemoveBackground = onRemoveBackground
            menu.addItem(removeBG)
        }
        menu.addItem(.separator())
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
    var onEditWidgets: (() -> Void)?
    var onToggleMic: (() -> Void)?
    var onToggleClosedMusic: (() -> Void)?
    var onChooseBackground: (() -> Void)?
    var onRemoveBackground: (() -> Void)?

    @objc func chooseBackground() {
        onChooseBackground?()
    }

    @objc func removeBackground() {
        onRemoveBackground?()
    }

    @objc func toggleMic() {
        onToggleMic?()
    }

    @objc func toggleClosedMusic() {
        onToggleClosedMusic?()
    }

    @objc func editWidgets() {
        onEditWidgets?()
    }

    @objc func clearShelf() {
        shelf?.clear()
    }

    @objc func airdropAll() {
        if let urls = shelf?.availableURLs() { AirDrop.send(urls) }
    }

    @objc func toggleLogin() {
        LoginItem.toggleWithFeedback()
    }
}

/// An on/off item in the settings menu.
struct MenuToggle {
    let title: String
    /// nil = a plain item without a checkmark.
    let isOn: Bool?
    let action: () -> Void
}
