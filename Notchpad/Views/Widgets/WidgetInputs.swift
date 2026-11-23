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

    static let none = WidgetActions()
}

/// Everything a widget shows, as plain values, so the same views render live data or demo data.
@MainActor
struct WidgetInputs {
    var music: MusicState
    var artwork: NSImage?
    var now: Date
    var reminders: [ReminderSummary]
    var remindersAccess: CalendarAccess
    var pendingReminderIDs: Set<String>
    var events: [EventSummary]
    var calendarAccess: CalendarAccess
    var focus: FocusTimer
    var lastFocusMinutes: Int
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
        return WidgetInputs(music: music, artwork: artwork, now: clock,
                            reminders: reminders, remindersAccess: remindersAccess,
                            pendingReminderIDs: pendingReminderIDs,
                            events: events, calendarAccess: calendarAccess,
                            focus: focus, lastFocusMinutes: lastFocusMinutes,
                            tailscale: tailscale, tailscaleBusy: tailscaleBusy,
                            tailscaleMessage: tailscaleMessage, copiedDeviceID: copiedDeviceID,
                            shelf: shelf, shelfDropTargeted: dropTargeted, actions: actions)
    }
}
