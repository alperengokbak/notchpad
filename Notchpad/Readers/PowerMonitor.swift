import Foundation
import IOKit.ps
import NotchpadCore

/// Tells us when the power source changes (charger in or out). Uses the public IOKit power
/// sources API; nothing polls, macOS calls us back.
@MainActor
final class PowerMonitor {
    var onChange: ((PowerState) -> Void)?
    private var source: CFRunLoopSource?

    func start() {
        guard source == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.onChange?(PowerMonitor.read()) }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        source = src
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        source = nil
    }

    /// The current power source and battery level.
    nonisolated static func read() -> PowerState {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return PowerState(onAC: false, percent: nil) }
        let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        var percent: Int?
        if let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
           let first = list.first,
           let desc = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any] {
            percent = desc[kIOPSCurrentCapacityKey] as? Int
        }
        return PowerState(onAC: type == kIOPMACPowerKey, percent: percent)
    }
}
