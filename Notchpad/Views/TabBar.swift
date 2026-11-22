import SwiftUI

enum PanelTab: String {
    case home, tailscale

    var title: String {
        switch self {
        case .home: "Home"
        case .tailscale: "Tailscale"
        }
    }
}

/// Small pills in the empty strip left of the notch.
struct TabBar: View {
    @Binding var selected: PanelTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach([PanelTab.home, .tailscale], id: \.self) { tab in
                Button { selected = tab } label: {
                    Text(tab.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selected == tab ? Color.black : Color(white: 0.67))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(selected == tab ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.13)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
