import Foundation

/// Lets only one background job of a kind run at a time (e.g. Tailscale status reads),
/// so a hung command can't pile up a queue of more calls behind it.
public struct SingleFlight: Sendable {
    private var running = false

    public init() {}

    /// True if the caller may start; false if one is already running.
    public mutating func tryStart() -> Bool {
        guard !running else { return false }
        running = true
        return true
    }

    public mutating func finish() {
        running = false
    }
}
