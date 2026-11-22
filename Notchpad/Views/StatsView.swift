import NotchpadCore
import SwiftUI

/// Right column: chip temperature and battery.
struct StatsView: View {
    let battery: BatteryStatus?
    let temperature: Int?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            label("Chip")
            Text(temperature.map { "\($0)°" } ?? "–").font(.system(size: 22, weight: .semibold))
            label("Battery").padding(.top, 8)
            HStack(spacing: 3) {
                if battery?.isPluggedIn == true {
                    Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(.yellow)
                }
                Text(battery.map { "\($0.percent)%" } ?? "–").font(.system(size: 22, weight: .semibold))
            }
            if let battery {
                Text(battery.detailText).font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                    .lineLimit(1).fixedSize()
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .medium)).tracking(0.6)
            .foregroundStyle(Color(white: 0.55))
    }
}
