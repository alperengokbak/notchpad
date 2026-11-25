import NotchpadCore
import SwiftUI

/// World clock widget: the time in his cities. "+" adds one (a menu by region), hover for ×.
struct WorldClockView: View {
    let rows: [ClockRow]
    let size: WidgetSize
    let onAdd: () -> Void
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("WORLD CLOCK").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    .foregroundStyle(Color(white: 0.55))
                Spacer()
                AddButton(help: "Add a city", action: onAdd)
            }
            ScrollView(.vertical) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: size == .wide ? 2 : 1),
                          alignment: .leading, spacing: size == .small ? 2 : 6) {
                    ForEach(rows, id: \.zoneID) { row in
                        ClockRowView(row: row, compact: size == .small, onRemove: { onRemove(row.zoneID) })
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
    }
}

private struct ClockRowView: View {
    let row: ClockRow
    let compact: Bool
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(row.city).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                if !compact {
                    Text([row.offset, row.day].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 10)).foregroundStyle(Color(white: 0.55)).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(Color(white: 0.5))
                }
                .buttonStyle(.plain).help("Remove \(row.city)")
            }
            Text(row.time).font(.system(size: compact ? 14 : 17, weight: .semibold).monospacedDigit())
        }
        .help(compact ? [row.offset, row.day].compactMap { $0 }.joined(separator: " · ") : row.city)
        .onHover { hovering = $0 }
    }
}
