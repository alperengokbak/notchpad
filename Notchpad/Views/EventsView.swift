import AppKit
import NotchpadCore
import SwiftUI

/// Middle column: the rest of today's events.
struct EventsView: View {
    let events: [EventSummary]
    let access: CalendarAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY").font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
            switch access {
            case .denied:
                Text("Calendar access is off").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                }
                .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
            case .unknown:
                EmptyView()
            case .granted:
                if events.isEmpty {
                    Text("Nothing else today").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                } else {
                    ForEach(events) { row($0) }
                }
            }
        }
    }

    private func row(_ e: EventSummary) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: e.red, green: e.green, blue: e.blue))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.tail)
                Text(DayEvents.timeText(e, calendar: .current)).font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.6))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
            }
        }
    }
}
