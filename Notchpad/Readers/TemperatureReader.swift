import Foundation

// Private IOKit HID functions (no public API exists for Apple Silicon temperatures).
// This is why Notchpad can't be sandboxed or go on the App Store.
private typealias HIDClient = OpaquePointer
@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> HIDClient?
@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: HIDClient, _ matching: CFDictionary)
@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: HIDClient) -> CFArray?
@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: OpaquePointer, _ key: CFString) -> CFTypeRef?
@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: OpaquePointer, _ type: Int64, _ options: Int32, _ timestamp: Int64) -> OpaquePointer?
@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: OpaquePointer, _ field: Int32) -> Double

/// Reads every temperature sensor. Returns an empty list if anything fails.
final class TemperatureReader {
    private let temperatureEventType: Int64 = 15
    private lazy var client: HIDClient? = {
        guard let c = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return nil }
        IOHIDEventSystemClientSetMatching(c, ["PrimaryUsagePage": 0xFF00, "PrimaryUsage": 5] as CFDictionary)
        return c
    }()

    func readAll() -> [(name: String, value: Double)] {
        guard let client, let services = IOHIDEventSystemClientCopyServices(client) as? [AnyObject] else { return [] }
        var result: [(name: String, value: Double)] = []
        for service in services {
            let s = OpaquePointer(Unmanaged.passUnretained(service).toOpaque())
            guard let name = IOHIDServiceClientCopyProperty(s, "Product" as CFString) as? String,
                  let event = IOHIDServiceClientCopyEvent(s, temperatureEventType, 0, 0)
            else { continue }
            let value = IOHIDEventGetFloatValue(event, Int32(temperatureEventType << 16))
            Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(event)).release()
            result.append((name, value))
        }
        return result
    }
}
