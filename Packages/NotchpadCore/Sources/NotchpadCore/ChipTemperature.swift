import Foundation

public enum ChipTemperature {
    /// One chip temperature from raw sensor readings, in whole °C.
    /// Uses the die sensors ("PMU tdie…"), or "…MTR Temp Sensor…" on Macs without them.
    /// Readings is a list because the same sensor name can appear more than once.
    public static func average(_ readings: [(name: String, value: Double)]) -> Int? {
        let valid = readings.filter { (1...130).contains($0.value) }
        var picked = valid.filter { $0.name.hasPrefix("PMU tdie") }
        if picked.isEmpty { picked = valid.filter { $0.name.contains("MTR Temp Sensor") } }
        guard !picked.isEmpty else { return nil }
        let mean = picked.reduce(0) { $0 + $1.value } / Double(picked.count)
        return Int(mean.rounded())
    }
}
