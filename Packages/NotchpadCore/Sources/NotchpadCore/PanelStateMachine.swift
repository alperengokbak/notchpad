import Foundation

/// Decides when the panel opens and closes. Pure logic: the window controller feeds it
/// pointer positions and clock ticks.
public struct PanelStateMachine: Sendable {
    public let openDelay: TimeInterval
    public let closeDelay: TimeInterval

    public private(set) var isOpen = false
    /// Debug: keeps the panel open (`--force-open`).
    public var forceOpen = false {
        didSet { if forceOpen { isOpen = true; pendingOpenAt = nil; pendingCloseAt = nil } }
    }

    private var pointerInside = false
    private var shelfDragActive = false
    private var pendingOpenAt: TimeInterval?
    private var pendingCloseAt: TimeInterval?

    public init(openDelay: TimeInterval = 0.15, closeDelay: TimeInterval = 0.3) {
        self.openDelay = openDelay
        self.closeDelay = closeDelay
    }

    /// True while a delayed open or close is waiting, so the controller only ticks then.
    public var hasPendingDeadline: Bool { pendingOpenAt != nil || pendingCloseAt != nil }

    /// `inside` means inside the hot zone while closed, inside the open panel while open.
    public mutating func pointer(inside: Bool, now: TimeInterval) {
        pointerInside = inside
        if isOpen {
            pendingOpenAt = nil
            if inside { pendingCloseAt = nil } else { scheduleClose(now: now) }
        } else {
            pendingCloseAt = nil
            if inside { if pendingOpenAt == nil { pendingOpenAt = now + openDelay } } else { pendingOpenAt = nil }
        }
    }

    public mutating func fileDragNearNotch(now: TimeInterval) {
        isOpen = true
        pendingOpenAt = nil
        pendingCloseAt = nil
    }

    public mutating func setShelfDragActive(_ active: Bool, now: TimeInterval) {
        shelfDragActive = active
        if active { pendingCloseAt = nil } else if isOpen && !pointerInside { scheduleClose(now: now) }
    }

    public mutating func tick(now: TimeInterval) {
        if let t = pendingOpenAt, now >= t {
            isOpen = true
            pendingOpenAt = nil
        }
        if let t = pendingCloseAt, now >= t {
            isOpen = false
            pendingCloseAt = nil
        }
    }

    private mutating func scheduleClose(now: TimeInterval) {
        guard !forceOpen, !shelfDragActive else { return }
        if pendingCloseAt == nil { pendingCloseAt = now + closeDelay }
    }
}
