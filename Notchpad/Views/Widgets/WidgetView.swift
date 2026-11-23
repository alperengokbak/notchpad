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
                      onCommand: a.music, onOpenMusic: a.openMusic)
        case (.music, _):
            MusicMedium(inputs: inputs)
        case (.shelf, .small):
            ShelfView(store: inputs.shelf, isDropTargeted: inputs.shelfDropTargeted, onDragActive: a.shelfDragActive)
        case (.shelf, .medium):
            ShelfView(store: inputs.shelf, isDropTargeted: inputs.shelfDropTargeted, onDragActive: a.shelfDragActive,
                      asGrid: true)
        case (.shelf, _):
            ShelfView(store: inputs.shelf, isDropTargeted: inputs.shelfDropTargeted, onDragActive: a.shelfDragActive,
                      asGrid: true, iconScale: 1.4)
        case (.reminders, .full):
            RemindersTab(inputs: inputs)
        case (.reminders, _):
            RemindersSection(inputs: inputs)
        case (.nextEvent, .small):
            NextEventView(events: inputs.events, access: inputs.calendarAccess)
        case (.nextEvent, _):
            TodayEventsView(events: inputs.events, access: inputs.calendarAccess)
        case (.focus, _):
            FocusCard(inputs: inputs)
        case (.tailscale, .full):
            TailscaleView(status: inputs.tailscale, busy: inputs.tailscaleBusy, message: inputs.tailscaleMessage,
                          copiedDeviceID: inputs.copiedDeviceID, onConnect: a.connectTailscale, onCopy: a.copyIP)
        case (.tailscale, _):
            TailscaleCompact(inputs: inputs)
        }
    }
}

/// Music, Medium: bigger artwork, with progress and controls across the column.
private struct MusicMedium: View {
    let inputs: WidgetInputs

    var body: some View {
        MusicView(state: inputs.music, artwork: inputs.artwork, now: inputs.now,
                  onCommand: inputs.actions.music, onOpenMusic: inputs.actions.openMusic, large: true)
    }
}

/// Next event, Medium: the rest of today's events.
private struct TodayEventsView: View {
    let events: [EventSummary]
    let access: CalendarAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY").font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
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
                    HStack(alignment: .top, spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5).fill(Color(red: e.red, green: e.green, blue: e.blue))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            Text(DayEvents.timeText(e, calendar: .current))
                                .font(.system(size: 11)).foregroundStyle(Color(white: 0.6))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
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
