import AppKit
import Combine
import NotchpadCore

/// Everything the panel shows. Readers write into it, views read from it.
@MainActor
final class AppModel: ObservableObject {
    @Published var isOpen = false
    /// Size of the real notch, so the closed shape matches it.
    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var battery: BatteryStatus?
    @Published var temperature: Int?

    private let batteryReader = BatteryReader()

    init() {
        battery = batteryReader.current()
        batteryReader.observe { [weak self] in
            guard let self else { return }
            self.battery = self.batteryReader.current()
        }
    }

    /// Called by the window controller right after the panel opens.
    func panelDidOpen() {}

    /// Called by the window controller right after the panel closes.
    func panelDidClose() {}
}
