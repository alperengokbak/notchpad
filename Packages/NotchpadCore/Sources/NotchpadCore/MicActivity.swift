import Foundation

/// Whether some app is using the microphone, and since when (wall clock).
public struct MicActivity: Equatable, Sendable {
    public private(set) var since: Date?

    public init() {}

    public var isActive: Bool { since != nil }

    /// Call whenever macOS reports the input device running state.
    public mutating func update(isRunning: Bool, now: Date) {
        if isRunning {
            if since == nil { since = now }
        } else {
            since = nil
        }
    }

    public func elapsed(now: Date) -> TimeInterval? {
        since.map { max(0, now.timeIntervalSince($0)) }
    }
}
