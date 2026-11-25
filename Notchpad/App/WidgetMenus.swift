import AppKit
import NotchpadCore

/// Right-click on a widget: its own actions at the top of the panel menu.
extension AppModel {
    /// The widget under a point of the open panel (top-left origin), if any. Nil in edit mode or while an editor shows.
    func widgetKind(atPanelPoint p: CGPoint) -> WidgetKind? {
        guard isOpen, !isEditing, editor == nil else { return nil }
        let origin = CGPoint(x: 22, y: notchSize.height + 4)
        let area = CGSize(width: NotchGeometry.openSize.width - 44,
                          height: NotchGeometry.openSize.height - notchSize.height - 4 - 18)
        let local = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
        return layout.selectedTab.widgets.first { w in
            WidgetGrid.frame(size: w.size, column: w.column, half: w.half, in: area, gap: WidgetGridView.gap).contains(local)
        }?.kind
    }

    /// Heading and items for the widget's section of the menu.
    func widgetMenuSection(for kind: WidgetKind) -> (title: String, items: [NSMenuItem]) {
        DebugTools.log("widget menu: \(kind.rawValue)")
        switch kind {
        case .music: return (musicSource.title, musicMenuItems())
        case .shelf: return ("Shelf", shelfMenuItems())
        case .reminders: return ("Reminders", [item("New reminder") { $0.newReminder() }, item("Open Reminders") { $0.openApp("com.apple.reminders") }])
        case .nextEvent: return ("Calendar", eventMenuItems())
        case .focus: return ("Focus", focusMenuItems())
        case .tailscale: return ("Tailscale", tailscaleMenuItems())
        case .launcher: return ("Shortcuts", launcherMenuItems())
        case .mirror: return ("Mirror", mirrorMenuItems())
        case .clipboard: return ("Clipboard", clipboardMenuItems())
        case .recentFiles: return ("Recent files", [item("Refresh") { $0.refreshRecentFilesNow() }])
        case .worldClock: return ("World clock", [clockCitiesItem()])
        case .quickNote: return ("Quick note", noteMenuItems())
        }
    }

    // MARK: Music

    private func musicMenuItems() -> [NSMenuItem] {
        guard music != .notRunning else {
            return [item("Open \(musicSource.appName)") { $0.openMusic() }]
        }
        let playing: Bool = { if case .playing = music { return true }; return false }()
        let state = musicMenu
        var items: [NSMenuItem] = []
        if playing && musicSource == .appleMusic {
            let add = NSMenuItem(title: "Add to playlist", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            if state.playlists.isEmpty {
                sub.addItem(disabled("No playlists of your own yet"))
            }
            for name in state.playlists {
                sub.addItem(item(name) { $0.addSongToPlaylist(name) })
            }
            add.submenu = sub
            items.append(add)
            items.append(item("Add to library") { $0.addSongToLibrary() })
            items.append(item("Favourite", on: state.favorited == true) { $0.toggleFavourite() })
            items.append(.separator())
        }
        // Spotify only: Apple Music on current macOS ignores shuffle and repeat set by script (tested 25 Nov 2026).
        if musicSource == .spotify {
            items.append(item("Shuffle", on: state.shuffle == true) { $0.setMusicShuffle(!(state.shuffle ?? false)) })
            items.append(item("Repeat", on: state.repeatMode == .all) { $0.setMusicRepeat(state.repeatMode == .all ? .off : .all) })
            items.append(.separator())
        }
        if playing { items.append(item("Copy song link") { $0.copySongLink() }) }
        items.append(item(musicSource == .appleMusic ? "Show in Music" : "Open Spotify") { $0.showSongInApp() })
        return items
    }

    /// Playlists and ticks for the Music menu, read in the background whenever the panel opens on
    /// a Music widget and when the song changes, so the right-click menu opens at once.
    func refreshMusicMenuState() {
        guard !Self.isDemo else {
            musicMenu = MusicMenuState(playlists: ["Road trip", "Study", "Gym"], favorited: false, shuffle: false, repeatMode: .off)
            return
        }
        guard Self.isRunning(musicSource) else { musicMenu = MusicMenuState(); return }
        let controller = musicController
        musicQueue.async { [weak self] in
            var state = controller.fetchMenuState()
            state.playlists = controller.fetchPlaylists()
            DispatchQueue.main.async {
                guard let self, controller.source == self.musicSource else { return }
                self.musicMenu = state
            }
        }
    }

    private func onMusic(_ log: String, _ work: @escaping @Sendable (MusicController) -> Void) {
        DebugTools.log("music menu: \(log)")
        guard !Self.isDemo else { return }
        let controller = musicController
        musicQueue.async { [weak self] in
            work(controller)
            DispatchQueue.main.async { self?.refreshMusicMenuState() }
        }
    }

    func addSongToPlaylist(_ name: String) {
        guard !Self.isDemo else { DebugTools.log("music menu: add to playlist \(name)"); showToast("Added to \(name)"); return }
        let controller = musicController
        showToast("Adding to \(name)…", seconds: 12)
        musicQueue.async { [weak self] in
            let result = controller.addToPlaylist(name)
            DispatchQueue.main.async {
                DebugTools.log("music menu: add to playlist \(name) = \(result.rawValue)")
                switch result {
                case .added: self?.showToast("Added to \(name)")
                case .alreadyThere: self?.showToast("Already in \(name)")
                case .failed: self?.showToast("Couldn't add to \(name)")
                }
            }
        }
    }

    func addSongToLibrary() {
        guard !Self.isDemo else { DebugTools.log("music menu: add to library"); showToast("Added to your library"); return }
        let controller = musicController
        showToast("Adding to your library…", seconds: 12)
        musicQueue.async { [weak self] in
            let result = controller.addToLibrary()
            DispatchQueue.main.async {
                DebugTools.log("music menu: add to library = \(result.rawValue)")
                switch result {
                case .added: self?.showToast("Added to your library")
                case .alreadyThere: self?.showToast("Already in your library")
                case .failed: self?.showToast("Couldn't add to your library")
                }
            }
        }
    }

    func toggleFavourite() {
        let on = !(musicMenu.favorited ?? false)
        musicMenu.favorited = on
        onMusic("favourite \(on)") { $0.setFavorited(on) }
    }

    func setMusicShuffle(_ on: Bool) {
        musicMenu.shuffle = on
        onMusic("shuffle \(on)") { $0.setShuffle(on) }
    }

    func setMusicRepeat(_ mode: RepeatMode) {
        musicMenu.repeatMode = mode
        onMusic("repeat \(mode.rawValue)") { $0.setRepeat(mode) }
    }

    /// Spotify: the song's open.spotify.com link. Apple Music: its music.apple.com page, found with
    /// Apple's public search (sends only the title and artist); a search page if nothing matches.
    func copySongLink() {
        guard case .playing(let song) = music else { return }
        if Self.isDemo {
            DebugTools.log("music menu: copy link \(song.title)")
            showToast("Link copied")
            return
        }
        let controller = musicController
        let country = Locale.current.region?.identifier ?? "GB"
        musicQueue.async { [weak self] in
            var link: URL?
            if controller.source == .spotify {
                link = controller.fetchSpotifyURI().flatMap(SongLink.spotifyWebURL(fromURI:))
            } else if let lookup = SongLink.appleLookupURL(title: song.title, artist: song.artist, country: country) {
                let request = URLRequest(url: lookup, timeoutInterval: 6)
                let semaphore = DispatchSemaphore(value: 0)
                let box = ResponseBox()
                URLSession.shared.dataTask(with: request) { d, _, _ in box.data = d; semaphore.signal() }.resume()
                semaphore.wait()
                link = box.data.flatMap { SongLink.parseAppleLookup($0, title: song.title, artist: song.artist) }
                    ?? SongLink.appleSearchPage(title: song.title, artist: song.artist)
            }
            DispatchQueue.main.async {
                guard let link else { self?.showToast("No link for this song"); return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link.absoluteString, forType: .string)
                DebugTools.log("music menu: copied \(link.host ?? "")")
                self?.showToast("Link copied")
            }
        }
    }

    func showSongInApp() {
        if musicSource == .appleMusic { onMusic("show in Music") { $0.reveal() } }
        if !Self.isDemo { openMusic() }
    }

    // MARK: Shelf

    private func shelfMenuItems() -> [NSMenuItem] {
        let urls = shelf.availableURLs()
        let has = !urls.isEmpty
        return [
            item("Open all", enabled: has) { _ in urls.forEach { NSWorkspace.shared.open($0) } },
            item("Show in Finder", enabled: has) { _ in NSWorkspace.shared.activateFileViewerSelecting(urls) },
            item("Copy file paths", enabled: has) { $0.copyText(urls.map(\.path).joined(separator: "\n"), toast: "Paths copied") },
            item("AirDrop all files", enabled: has) { _ in AirDrop.send(urls) },
            .separator(),
            item("Clear shelf", enabled: !shelf.items.isEmpty) { $0.shelf.clear() },
        ]
    }

    // MARK: Calendar

    private func eventMenuItems() -> [NSMenuItem] {
        var items = [item("New event") { $0.newEvent() }]
        let upcoming = DayEvents.upcoming(events, now: Date(), calendar: .current, limit: 10)
        if let next = upcoming.first(where: { $0.meetingURL != nil }), let url = next.meetingURL {
            items.append(item("Join \u{201C}\(next.title)\u{201D}") { model in
                DebugTools.log("join meeting: \(url.host ?? "")")
                if !Self.isDemo { NSWorkspace.shared.open(url) }
                model.showToast("Opening the meeting")
            })
        }
        items.append(item("Open Calendar") { $0.openApp("com.apple.iCal") })
        return items
    }

    // MARK: Focus

    private func focusMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        if focus.isActive {
            items.append(item(focus.isPaused ? "Resume" : "Pause") { $0.togglePauseFocus() })
            items.append(item("Stop") { $0.stopFocus() })
        } else {
            items.append(item("Start 25 min focus") { $0.startFocus(.focus, minutes: 25) })
            items.append(item("Start 50 min focus") { $0.startFocus(.focus, minutes: 50) })
        }
        items.append(.separator())
        let today = focusLog.minutesToday(now: Date(), calendar: .current)
        items.append(item("Clear today\u{2019}s focus history", enabled: today > 0) { $0.clearTodaysFocus() })
        return items
    }

    // MARK: Tailscale

    private func tailscaleMenuItems() -> [NSMenuItem] {
        let connected = tailscale?.state == .connected
        var items = [item(connected ? "Disconnect" : "Connect", enabled: !tailscaleBusy) { $0.connectTailscale(!connected) }]
        let me = tailscale?.devices.first { $0.isSelf }
        items.append(item("Copy this Mac\u{2019}s IP", enabled: me?.ipv4 != nil) { model in
            if let me { model.copyIP(me); model.showToast("IP copied") }
        })
        return items
    }

    // MARK: Shortcuts

    private func launcherMenuItems() -> [NSMenuItem] {
        refreshShortcutNames()
        let shortcuts = NSMenuItem(title: "Add shortcut", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        if shortcutNames.isEmpty { sub.addItem(disabled("No shortcuts found in the Shortcuts app")) }
        for name in shortcutNames { sub.addItem(item(name) { $0.addLauncherShortcut(name) }) }
        shortcuts.submenu = sub
        return [item("Add app\u{2026}") { $0.addLauncherApp() }, shortcuts, item("Add folder\u{2026}") { $0.addLauncherFolder() }]
    }

    // MARK: Mirror

    private func mirrorMenuItems() -> [NSMenuItem] {
        [item("Flip image", on: mirrorFlipped) { $0.mirrorFlipped.toggle() },
         item("Turn camera off", enabled: camera.state == .running || camera.state == .starting) { $0.camera.stop() }]
    }

    // MARK: Clipboard

    private func clipboardMenuItems() -> [NSMenuItem] {
        [item("Pause recording", on: clipboardPaused) { $0.clipboardPaused.toggle() },
         item("Clear history", enabled: !clipboard.history.entries.isEmpty) { $0.clipboard.clear() }]
    }

    // MARK: World clock

    private func clockCitiesItem() -> NSMenuItem {
        let add = NSMenuItem(title: "Add city", action: nil, keyEquivalent: "")
        let regions = NSMenu()
        for group in WorldClock.zonesByRegion() {
            let regionItem = NSMenuItem(title: group.region, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for zone in group.zones {
                sub.addItem(item(WorldClock.cityName(zone), on: worldClockZones.contains(zone)) { $0.toggleClockZone(zone) })
            }
            regionItem.submenu = sub
            regions.addItem(regionItem)
        }
        add.submenu = regions
        return add
    }

    // MARK: Quick note

    private func noteMenuItems() -> [NSMenuItem] {
        let has = !quickNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return [
            item("Copy note", enabled: has) { $0.copyText($0.quickNote, toast: "Note copied") },
            item("Save to Apple Notes", enabled: has) { $0.saveNoteToAppleNotes() },
            .separator(),
            item("Clear note\u{2026}", enabled: has) { $0.confirmClearNote() },
        ]
    }

    /// A new note in the default Notes folder; Notes opens if it's closed. macOS asks once to allow it.
    func saveNoteToAppleNotes() {
        let body = NoteExport.html(quickNote)
        guard !Self.isDemo else { DebugTools.log("note to Notes: \(body.count) chars"); showToast("Saved to Notes"); return }
        let script = "tell application \"Notes\" to make new note with properties {body:\(AppleScriptText.quote(body))}"
        DispatchQueue.global().async { [weak self] in
            let ok = AppleScriptRunner().run(script) != nil
            DispatchQueue.main.async {
                DebugTools.log("note to Notes: ok=\(ok)")
                self?.showToast(ok ? "Saved to Notes" : "Couldn't save to Notes")
            }
        }
    }

    private func confirmClearNote() {
        let alert = NSAlert()
        alert.messageText = "Clear the quick note?"
        alert.informativeText = "The text can't be brought back."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { quickNote = "" }
    }

    // MARK: Helpers

    private func copyText(_ text: String, toast: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(toast)
    }

    func openApp(_ bundleID: String) {
        DebugTools.log("open app: \(bundleID)")
        guard !Self.isDemo, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    /// A short message at the bottom of the open panel ("Added to Study").
    func showToast(_ text: String, seconds: TimeInterval = 2.2) {
        toast = text
        DebugTools.log("toast: \(text)")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.toast == text { self?.toast = nil }
        }
    }

    private func item(_ title: String, on: Bool? = nil, enabled: Bool = true,
                      _ action: @escaping @MainActor (AppModel) -> Void) -> NSMenuItem {
        let menuItem = ClosureMenuItem(title) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { action(self) }
        }
        if let on { menuItem.state = on ? .on : .off }
        if !enabled {
            menuItem.isEnabled = false
            menuItem.target = nil
            menuItem.action = nil
        }
        return menuItem
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }
}

/// Hands a downloaded reply from URLSession's queue to the waiting music queue.
private final class ResponseBox: @unchecked Sendable {
    var data: Data?
}
