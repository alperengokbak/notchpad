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
    private let temperatureReader = TemperatureReader()
    private var openTimers: [Timer] = []

    init() {
        battery = batteryReader.current()
        batteryReader.observe { [weak self] in
            guard let self else { return }
            self.battery = self.batteryReader.current()
        }
    }

    /// Called by the window controller right after the panel opens.
    func panelDidOpen() {
        refreshTemperature()
        every(2) { $0.refreshTemperature() }
    }

    /// Called by the window controller right after the panel closes. Nothing polls while closed.
    func panelDidClose() {
        openTimers.forEach { $0.invalidate() }
        openTimers.removeAll()
    }

    /// Runs `action` every `seconds` until the panel closes.
    private func every(_ seconds: TimeInterval, _ action: @escaping @MainActor (AppModel) -> Void) {
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        openTimers.append(timer)
    }

    private func refreshTemperature() {
        temperature = ChipTemperature.average(temperatureReader.readAll())
    }
}
