import AppKit
import NotchpadCore
import SwiftUI

/// One widget at one size. The only place that maps (kind, size) to a view.
struct WidgetView: View {
    let kind: WidgetKind
    let size: WidgetSize
    let inputs: WidgetInputs

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
    }

    @ViewBuilder private var content: some View {
        let a = inputs.actions
        switch (kind, size) {
        case (.music, .small):
            MusicView(state: inputs.music, artwork: inputs.artwork, now: inputs.now,
                      onCommand: a.music, onOpenMusic: a.openMusic, onSeek: a.seekMusic, appName: inputs.musicAppName,
                      volume: inputs.volume, onSetVolume: a.setVolume, onToggleMute: a.toggleMute)
        case (.music, _):
            MusicMedium(inputs: inputs)
        case (.shelf, .small):
            ShelfView(store: inputs.shelf, isDropTargeted: inputs.shelfDropTargeted, onDragActive: a.shelfDragActive, newestFirst: inputs.shelfNewestFirst)
        case (.shelf, .medium):
            ShelfView(store: inputs.shelf, isDropTargeted: inputs.shelfDropTargeted, onDragActive: a.shelfDragActive, newestFirst: inputs.shelfNewestFirst,
                      asGrid: true)
        case (.shelf, _):
            ShelfView(store: inputs.shelf, isDropTargeted: inputs.shelfDropTargeted, onDragActive: a.shelfDragActive, newestFirst: inputs.shelfNewestFirst,
                      asGrid: true, iconScale: 1.4)
        case (.reminders, .full):
            RemindersTab(inputs: inputs)
        case (.reminders, _):
            RemindersSection(inputs: inputs)
        case (.nextEvent, .small):
            NextEventView(events: inputs.events, access: inputs.calendarAccess,
                          onNew: a.newEvent, onEdit: a.editEvent, onDelete: a.deleteEvent)
        case (.nextEvent, _):
            TodayEventsView(inputs: inputs)
        case (.focus, _):
            FocusCard(inputs: inputs)
        case (.tailscale, .full):
            TailscaleView(status: inputs.tailscale, busy: inputs.tailscaleBusy, message: inputs.tailscaleMessage,
                          copiedDeviceID: inputs.copiedDeviceID, onConnect: a.connectTailscale, onCopy: a.copyIP)
        case (.tailscale, _):
            TailscaleCompact(inputs: inputs)
        case (.launcher, _):
            LauncherView(inputs: inputs, size: size)
        case (.mirror, _):
            MirrorView(camera: inputs.camera, demoImage: inputs.mirrorDemoImage, flipped: inputs.mirrorFlipped)
        case (.clipboard, _):
            ClipboardView(monitor: inputs.clipboard, now: inputs.now, paused: inputs.clipboardPaused)
        case (.quickNote, _):
            QuickNoteView(inputs: inputs)
        case (.worldClock, _):
            WorldClockView(rows: inputs.clockRows, size: size, onAdd: a.addClockCity, onRemove: a.removeClockCity)
        case (.recentFiles, _):
            RecentFilesView(files: inputs.recentFiles, now: inputs.now, onOpen: a.openRecentFile)
        }
    }
}

/// Music, Medium: bigger artwork, with progress and controls across the column.
private struct MusicMedium: View {
    let inputs: WidgetInputs

    var body: some View {
        MusicView(state: inputs.music, artwork: inputs.artwork, now: inputs.now,
                  onCommand: inputs.actions.music, onOpenMusic: inputs.actions.openMusic,
                  onSeek: inputs.actions.seekMusic, appName: inputs.musicAppName, large: true,
                  volume: inputs.volume, onSetVolume: inputs.actions.setVolume, onToggleMute: inputs.actions.toggleMute)
    }
}

/// Next event, Medium: the rest of today's events. Click one to edit it; "+" adds one.
private struct TodayEventsView: View {
    let inputs: WidgetInputs
    private var events: [EventSummary] { inputs.events }
    private var access: CalendarAccess { inputs.calendarAccess }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            EventHeader(title: "TODAY", access: access, onNew: inputs.actions.newEvent)
            switch access {
            case .denied:
                Text("Calendar off").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
            case .unknown:
                EmptyView()
            case .granted:
                if events.isEmpty {
                    Text("Nothing else today").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                }
                ForEach(events) { e in
                    EventRow(event: e, onTap: { inputs.actions.editEvent(e) },
                             onDelete: e.isEditable ? { inputs.actions.deleteEvent(e) } : nil)
                }
            }
        }
    }
}

/// Tailscale, Medium: state, the one button, and how many devices are online.
private struct TailscaleCompact: View {
    let inputs: WidgetInputs

    private var state: TailscaleState? { inputs.tailscale?.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TAILSCALE").font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
            HStack(spacing: 8) {
                Circle().fill(state == .connected ? Color.green : Color(white: 0.4)).frame(width: 8, height: 8)
                Text(inputs.tailscaleMessage ?? state?.text ?? " ").font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            if let devices = inputs.tailscale?.devices, !devices.isEmpty, state == .connected {
                Text("\(devices.filter(\.isOnline).count) of \(devices.count) online")
                    .font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
            }
            button
        }
    }

    @ViewBuilder private var button: some View {
        if inputs.tailscaleBusy {
            ProgressView().controlSize(.small)
        } else {
            switch state {
            case .connected: pill("Disconnect") { inputs.actions.connectTailscale(false) }
            case .notConnected, .connecting: pill("Connect") { inputs.actions.connectTailscale(true) }
            case .needsLogin:
                pill("Open Tailscale") { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Tailscale.app")) }
            case .notInstalled, nil: EmptyView()
            }
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(Color.white)).contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
