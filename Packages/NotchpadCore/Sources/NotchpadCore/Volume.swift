import Foundation

/// The Mac's output volume as the Music widget's volume bar shows it.
public struct VolumeLevel: Equatable, Sendable {
    /// 0…1.
    public var volume: Double
    public var muted: Bool
    /// False when the output has no volume of its own (some HDMI displays, digital outputs).
    public var settable: Bool

    public init(volume: Double, muted: Bool, settable: Bool = true) {
        self.volume = min(max(volume, 0), 1)
        self.muted = muted
        self.settable = settable
    }

    public static let unavailable = VolumeLevel(volume: 0, muted: false, settable: false)

    /// Where the bar is filled to: empty while muted, like the macOS volume display.
    public var shownFraction: Double { muted ? 0 : volume }

    /// SF Symbol for the speaker button.
    public var symbolName: String {
        if muted || volume < 0.005 { return "speaker.slash.fill" }
        if volume < 0.34 { return "speaker.wave.1.fill" }
        if volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    /// Dragging or clicking the bar. Above zero it also unmutes, like the volume keys do.
    public func setting(_ fraction: Double) -> VolumeLevel {
        guard settable else { return self }
        let v = min(max(fraction, 0), 1)
        return VolumeLevel(volume: v, muted: v > 0 ? false : muted, settable: true)
    }

    /// Clicking the speaker. Unmuting at zero would still be silent, so it comes back at a quarter.
    public func toggledMute() -> VolumeLevel {
        guard settable else { return self }
        if volume < 0.005 { return VolumeLevel(volume: 0.25, muted: false, settable: true) }
        return VolumeLevel(volume: volume, muted: !muted, settable: true)
    }

    /// The vertical bar (Small size): the bottom is 0, the top is 1.
    public static func fraction(y: Double, height: Double) -> Double {
        guard height > 0 else { return 0 }
        return min(max(1 - y / height, 0), 1)
    }
}
