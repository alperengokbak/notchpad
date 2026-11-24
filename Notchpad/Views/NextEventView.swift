import AppKit
import NotchpadCore
import SwiftUI

/// Right column, top: the next event left today. Click it to edit; "+" adds one.
struct NextEventView: View {
    let events: [EventSummary]
    let access: CalendarAccess
    var onNew: () -> Void = {}
    var onEdit: (EventSummary) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            EventHeader(title: "NEXT", access: access, onNew: onNew)
            switch access {
            case .denied:
                Text("Calendar off").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
            case .unknown:
                EmptyView()
            case .granted:
                if let e = events.first {
                    EventRow(event: e, lines: 2, startOnly: true) { onEdit(e) }
                } else {
                    Text("Nothing else today").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "NEXT" / "TODAY" with the "+" on the right.
struct EventHeader: View {
    let title: String
    let access: CalendarAccess
    let onNew: () -> Void

    var body: some View {
        HStack {
            Text(title).font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
            Spacer()
            if access == .granted { AddButton(help: "New event", action: onNew) }
        }
    }
}

/// One event: calendar colour bar, title, time. Clicking it opens the editor.
struct EventRow: View {
    let event: EventSummary
    var lines = 1
    /// Only the start time (the Small widget has no room for "15:00 – 17:00").
    var startOnly = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5).fill(Color(red: event.red, green: event.green, blue: event.blue))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title).font(.system(size: 12, weight: .semibold)).lineLimit(lines)
                    Text(time).font(.system(size: 11)).foregroundStyle(Color(white: 0.6))
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(event.isEditable ? "Edit" : "Show")
    }

    private var time: String {
        let text = DayEvents.timeText(event, calendar: .current)
        return startOnly ? (text.components(separatedBy: " – ").first ?? text) : text
    }
}
