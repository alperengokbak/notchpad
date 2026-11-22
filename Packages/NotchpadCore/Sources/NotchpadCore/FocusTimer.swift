import Foundation

public enum FocusKind: Equatable, Sendable {
    case focus, rest
}

/// The focus/break countdown. Time comes from wall-clock dates, so sleep doesn't make it drift.
public struct FocusTimer: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case running(FocusKind, endsAt: Date)
        case paused(FocusKind, remaining: TimeInterval)
        case done(FocusKind)
    }

    public private(set) var phase: Phase = .idle

    public init() {}

    /// Running or paused (what the closed-notch countdown shows).
    public var isActive: Bool {
        switch phase {
        case .running, .paused: true
        default: false
        }
    }

    public var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    public var kind: FocusKind? {
        switch phase {
        case .idle: nil
        case .running(let k, _), .paused(let k, _), .done(let k): k
        }
    }

    public mutating func start(_ kind: FocusKind, minutes: Int, now: Date) {
        phase = .running(kind, endsAt: now.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    public mutating func pause(now: Date) {
        guard case .running(let k, let end) = phase else { return }
        phase = .paused(k, remaining: max(0, end.timeIntervalSince(now)))
    }

    public mutating func resume(now: Date) {
        guard case .paused(let k, let left) = phase else { return }
        phase = .running(k, endsAt: now.addingTimeInterval(left))
    }

    public mutating func stop() {
        phase = .idle
    }

    /// Seconds left, or nil when nothing is counting down.
    public func remaining(now: Date) -> TimeInterval? {
        switch phase {
        case .running(_, let end): max(0, end.timeIntervalSince(now))
        case .paused(_, let left): left
        default: nil
        }
    }

    /// Call every second. Returns true exactly once, when the countdown reaches zero.
    public mutating func tick(now: Date) -> Bool {
        guard case .running(let k, let end) = phase, now >= end else { return false }
        phase = .done(k)
        return true
    }

    /// "24:13" (rounded up, like a countdown).
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
