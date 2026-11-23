import NotchpadCore
import SwiftUI

/// Small pills in the empty strip left of the notch, one per tab.
struct TabBar: View {
    let tabs: [TabPage]
    let selectedID: UUID
    let onSelect: (UUID) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button { onSelect(tab.id) } label: {
                    Text(tab.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selectedID == tab.id ? Color.black : Color(white: 0.67))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(selectedID == tab.id ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.13)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
