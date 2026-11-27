import Foundation

// MARK: Swipe on the notch

public enum SwipeAction: Equatable, Sendable {
    case next, previous
}

/// Turns two-finger trackpad scrolls over the notch into "next / previous song".
/// Fingers moving left = next, right = previous. Fires once per swipe; the coasting after the
/// fingers lift (momentum) is ignored, and mostly-vertical moves (scrolling a list) never count.
public struct SwipeDetector: Sendable {
    public enum Phase: Sendable { case began, changed, ended, other }

    /// Finger travel (points) before a swipe counts.
    public static let threshold: Double = 50

    private var fingerDX: Double = 0
    private var dy: Double = 0
    private var fired = false

    public init() {}

    /// `inverted` = natural scrolling (the event's isDirectionInvertedFromDevice).
    public mutating func feed(dx: Double, dy: Double, phase: Phase, momentum: Bool, inverted: Bool) -> SwipeAction? {
        if momentum { return nil }
        switch phase {
        case .began:
            reset()
            return nil
        case .ended, .other:
            reset()
            return nil
        case .changed:
            fingerDX += inverted ? dx : -dx
            self.dy += dy
            guard !fired, abs(fingerDX) >= Self.threshold, abs(fingerDX) > 1.5 * abs(self.dy) else { return nil }
            fired = true
            return fingerDX < 0 ? .next : .previous
        }
    }

    private mutating func reset() {
        fingerDX = 0
        dy = 0
        fired = false
    }
}

// MARK: Shelf order

public enum ShelfOrder {
    /// The shelf keeps files in the order they were added; "Newest files first" shows them reversed.
    public static func arrange<T>(_ items: [T], newestFirst: Bool) -> [T] {
        newestFirst ? items.reversed() : items
    }

    /// Pinned files first, then the rest; "Newest files first" reorders within each group.
    public static func arrange(shelf items: [ShelfItem], newestFirst: Bool) -> [ShelfItem] {
        arrange(items.filter(\.pinned), newestFirst: newestFirst)
            + arrange(items.filter { !$0.pinned }, newestFirst: newestFirst)
    }
}

// MARK: Charging

/// The Mac's power source, reduced to what the charging animation needs.
public struct PowerState: Equatable, Sendable {
    public var onAC: Bool
    public var percent: Int?

    public init(onAC: Bool, percent: Int?) {
        self.onAC = onAC
        self.percent = percent
    }

    /// True only at the moment the charger is plugged in (not at launch, not while it stays in).
    public static func justPluggedIn(previous: PowerState?, current: PowerState) -> Bool {
        guard let previous else { return false }
        return !previous.onAC && current.onAC
    }
}
