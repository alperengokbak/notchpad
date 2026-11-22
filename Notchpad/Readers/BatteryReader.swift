import Foundation
import IOKit.ps
import NotchpadCore

/// Reads the internal battery. macOS pushes changes, so nothing polls.
@MainActor
final class BatteryReader {
    private var source: CFRunLoopSource?
    private var onChange: (() -> Void)?

    func current() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
            else { continue }
            return BatteryStatus(description: desc)
        }
        return nil
    }

    func observe(_ onChange: @escaping () -> Void) {
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let reader = Unmanaged<BatteryReader>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { reader.onChange?() }
        }, context)?.takeRetainedValue() else { return }
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }
}
