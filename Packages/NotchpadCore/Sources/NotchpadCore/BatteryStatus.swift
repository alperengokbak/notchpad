import Foundation

/// Battery state, parsed from an IOPowerSources description dictionary.
public struct BatteryStatus: Equatable, Sendable {
    public var percent: Int
    public var isPluggedIn: Bool
    public var isCharging: Bool
    public var minutesToEmpty: Int?
    public var minutesToFull: Int?

    public init?(description d: [String: Any]) {
        guard let current = (d["Current Capacity"] as? NSNumber)?.doubleValue,
              let max = (d["Max Capacity"] as? NSNumber)?.doubleValue, max > 0
        else { return nil }
        percent = Int((current / max * 100).rounded())
        isPluggedIn = (d["Power Source State"] as? String) == "AC Power"
        isCharging = (d["Is Charging"] as? NSNumber)?.boolValue ?? false
        minutesToEmpty = Self.minutes(d["Time to Empty"])
        minutesToFull = Self.minutes(d["Time to Full Charge"])
    }

    /// The grey line under the percentage.
    public var detailText: String {
        if !isPluggedIn {
            return minutesToEmpty.map { "\(Self.clock($0)) left" } ?? "Calculating…"
        }
        if isCharging {
            return minutesToFull.flatMap { $0 > 0 ? "\(Self.clock($0)) to full" : nil } ?? "Charging"
        }
        return "Plugged in"
    }

    /// macOS reports -1 while it's still working the time out.
    private static func minutes(_ value: Any?) -> Int? {
        guard let m = (value as? NSNumber)?.intValue, m >= 0 else { return nil }
        return m
    }

    private static func clock(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
