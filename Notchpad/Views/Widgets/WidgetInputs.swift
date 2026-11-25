import AppKit
import NotchpadCore
import SwiftUI

/// What widgets can do. Gallery previews use `.none`, so nothing they show can act.
@MainActor
struct WidgetActions {
    var music: (MusicCommand) -> Void = { _ in }
    var openMusic: () -> Void = {}
    var tickReminder: (String) -> Void = { _ in }
    var openFullReminders: () -> Void = {}
    var startFocus: (FocusKind, Int) -> Void = { _, _ in }
    var togglePauseFocus: () -> Void = {}
    var stopFocus: () -> Void = {}
    var connectTailscale: (Bool) -> Void = { _ in }
    var copyIP: (TailscaleDevice) -> Void = { _ in }
    var shelfDragActive: (Bool) -> Void = { _ in }
    var newReminder: () -> Void = {}
    var editReminder: (String) -> Void = { _ in }
    var newEvent: () -> Void = {}
    var editEvent: (EventSummary) -> Void = { _ in }
    var deleteReminder: (String) -> Void = { _ in }
    var deleteEvent: (EventSummary) -> Void = { _ in }
    var seekMusic: (TimeInterval) -> Void = { _ in }
    var setVolume: (Double) -> Void = { _ in }
    var toggleMute: () -> Void = {}
    var stepFocus: (Int) -> Void = { _ in }
    var beginFocusTyping: () -> Void = {}
    var endFocusTyping: (String?) -> Void = { _ in }
    var startFocusFromWidget: (String?) -> Void = { _ in }
    var launch: (LauncherItem) -> Void = { _ in }
    var removeLauncherItem: (UUID) -> Void = { _ in }
    var addLauncherApp: () -> Void = {}
    var addLauncherFolder: () -> Void = {}
    var addLauncherShortcut: (String) -> Void = { _ in }
    var refreshShortcutNames: () -> Void = {}
    var dropOnLauncherFolder: (LauncherItem, [URL]) -> Void = { _, _ in }
    var showLauncherAddMenu: () -> Void = {}
    var moveLauncherItem: (UUID, UUID) -> Void = { _, _ in }
    var openRecentFile: (RecentFile) -> Void = { _ in }
    var addClockCity: () -> Void = {}
    var removeClockCity: (String) -> Void = { _ in }
    var setQuickNote: (String) -> Void = { _ in }
    var beginNote: () -> Void = {}
    var endNote: () -> Void = {}

    static let none = WidgetActions()
}

/// Everything a widget shows, as plain values, so the same views render live data or demo data.
@MainActor
struct WidgetInputs {
    var music: MusicState
    /// "Music" or "Spotify", for the "Open …" button.
    var musicAppName: String
    /// The Mac's output volume (the Music widget's volume bar).
    var volume = VolumeLevel(volume: 0.6, muted: false)
    var artwork: NSImage?
    var now: Date
    var reminders: [ReminderSummary]
    var remindersAccess: CalendarAccess
    var pendingReminderIDs: Set<String>
    var events: [EventSummary]
    var calendarAccess: CalendarAccess
    var focus: FocusTimer
    var lastFocusMinutes: Int
    /// The length − / + has picked.
    var focusMinutes: Int = 25
    /// The focus length text box is open.
    var editingFocusMinutes = false
    /// Shortcuts widget: its icons, his shortcut names (for the + menu), and the folder that just took a drop.
    var launcherItems: [LauncherItem] = []
    var shortcutNames: [String] = []
    var copiedLauncherID: UUID?
    /// Mirror widget: the camera, or a drawn picture for previews and demo screenshots.
    var camera: CameraMirror = DemoData.previewCamera
    var mirrorDemoImage: NSImage?
    var shelfNewestFirst = false
    var clipboard: ClipboardMonitor = DemoData.previewClipboard
    var recentFiles: [RecentFile] = []
    var clockRows: [ClockRow] = []
    var focusHistory: String?
    var quickNote = ""
    var editingNote = false
    var tailscale: TailscaleStatus?
    var tailscaleBusy: Bool
    var tailscaleMessage: String?
    var copiedDeviceID: String?
    var shelf: ShelfStore
    var shelfDropTargeted: Bool
    var actions: WidgetActions
}

extension AppModel {
    func widgetInputs(dropTargeted: Bool) -> WidgetInputs {
        var actions = WidgetActions()
        actions.music = { [weak self] in self?.sendMusic($0) }
        actions.openMusic = { [weak self] in self?.openMusic() }
        actions.tickReminder = { [weak self] in self?.toggleReminder($0) }
        actions.openFullReminders = { [weak self] in self?.openFullReminders() }
        actions.startFocus = { [weak self] in self?.startFocus($0, minutes: $1) }
        actions.togglePauseFocus = { [weak self] in self?.togglePauseFocus() }
        actions.stopFocus = { [weak self] in self?.stopFocus() }
        actions.connectTailscale = { [weak self] in self?.connectTailscale($0) }
        actions.copyIP = { [weak self] in self?.copyIP($0) }
        actions.shelfDragActive = { [weak self] in self?.onShelfDragActive?($0) }
        actions.newReminder = { [weak self] in self?.newReminder() }
        actions.editReminder = { [weak self] in self?.editReminder($0) }
        actions.newEvent = { [weak self] in self?.newEvent() }
        actions.editEvent = { [weak self] in self?.editEvent($0) }
        actions.deleteReminder = { [weak self] in self?.deleteReminder($0) }
        actions.deleteEvent = { [weak self] in self?.deleteEvent($0) }
        actions.seekMusic = { [weak self] in self?.seekMusic(to: $0) }
        actions.setVolume = { [weak self] in self?.setVolume($0) }
        actions.toggleMute = { [weak self] in self?.toggleMute() }
        actions.stepFocus = { [weak self] in self?.stepFocus($0) }
        actions.beginFocusTyping = { [weak self] in self?.beginFocusMinutesTyping() }
        actions.endFocusTyping = { [weak self] in self?.endFocusMinutesTyping($0) }
        actions.startFocusFromWidget = { [weak self] in self?.startFocusFromWidget(typed: $0) }
        actions.launch = { [weak self] in self?.launch($0) }
        actions.removeLauncherItem = { [weak self] in self?.launcher.remove($0) }
        actions.addLauncherApp = { [weak self] in self?.addLauncherApp() }
        actions.addLauncherFolder = { [weak self] in self?.addLauncherFolder() }
        actions.addLauncherShortcut = { [weak self] in self?.addLauncherShortcut($0) }
        actions.refreshShortcutNames = { [weak self] in self?.refreshShortcutNames() }
        actions.dropOnLauncherFolder = { [weak self] in self?.dropOnLauncherFolder($0, $1) }
        actions.showLauncherAddMenu = { [weak self] in self?.showLauncherAddMenu() }
        actions.moveLauncherItem = { [weak self] in self?.moveLauncherItem($0, onto: $1) }
        actions.openRecentFile = { [weak self] in self?.openRecentFile($0) }
        actions.addClockCity = { [weak self] in self?.showClockAddMenu() }
        actions.removeClockCity = { [weak self] in self?.removeClockZone($0) }
        actions.setQuickNote = { [weak self] in self?.quickNote = $0 }
        actions.beginNote = { [weak self] in self?.beginNoteEditing() }
        actions.endNote = { [weak self] in self?.endNoteEditing() }
        var inputs = WidgetInputs(music: music, musicAppName: musicSource.appName, artwork: artwork, now: clock,
                            reminders: reminders, remindersAccess: remindersAccess,
                            pendingReminderIDs: pendingReminderIDs,
                            events: events, calendarAccess: calendarAccess,
                            focus: focus, lastFocusMinutes: lastFocusMinutes, focusMinutes: focusMinutes,
                            tailscale: tailscale, tailscaleBusy: tailscaleBusy,
                            tailscaleMessage: tailscaleMessage, copiedDeviceID: copiedDeviceID,
                            shelf: shelf, shelfDropTargeted: dropTargeted, actions: actions)
        inputs.editingFocusMinutes = editingFocusMinutes
        inputs.volume = volume
        inputs.launcherItems = launcher.items
        inputs.shortcutNames = shortcutNames
        inputs.copiedLauncherID = copiedLauncherID
        inputs.camera = camera
        inputs.mirrorDemoImage = Self.isDemo && DebugTools.argument(after: "--editor") != "mirror-busy" ? DemoData.mirrorImage() : nil
        inputs.shelfNewestFirst = shelfNewestFirst
        inputs.clipboard = clipboard
        inputs.recentFiles = recentFiles
        inputs.clockRows = clockRows
        inputs.focusHistory = focusHistoryText
        inputs.quickNote = quickNote
        inputs.editingNote = editingNote
        return inputs
    }
}
