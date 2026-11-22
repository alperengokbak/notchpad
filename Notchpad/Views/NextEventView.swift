import AppKit
import NotchpadCore
import SwiftUI

/// Right column, top: the next event left today.
struct NextEventView: View {
    let events: [EventSummary]
    let access: CalendarAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("NEXT").font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
            switch access {
            case .denied:
                Text("Calendar off").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
            case .unknown:
                EmptyView()
            case .granted:
                if let e = events.first {
                    HStack(alignment: .top, spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5).fill(Color(red: e.red, green: e.green, blue: e.blue))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.title).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                            Text(DayEvents.timeText(e, calendar: .current).components(separatedBy: " – ").first ?? "")
                                .font(.system(size: 11)).foregroundStyle(Color(white: 0.6))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                            NSWorkspace.shared.openApplication(at: url, configuration: .init())
                        }
                    }
                } else {
                    Text("Nothing else today").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
