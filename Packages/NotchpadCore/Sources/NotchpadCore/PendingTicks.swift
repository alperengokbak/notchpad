import Foundation

/// Reminders ticked in the last moment, each with its own token, so an older timer
/// can't complete a reminder that was unticked and ticked again.
public struct PendingTicks: Equatable, Sendable {
    private var tokens: [String: UUID] = [:]

    public init() {}

    public func contains(_ id: String) -> Bool { tokens[id] != nil }

    public mutating func tick(_ id: String) -> UUID {
        let token = UUID()
        tokens[id] = token
        return token
    }

    public mutating func untick(_ id: String) {
        tokens[id] = nil
    }

    public func shouldCommit(_ id: String, token: UUID) -> Bool {
        tokens[id] == token
    }

    /// True (and forgets the tick) if this token is still the current one.
    public mutating func commit(_ id: String, token: UUID) -> Bool {
        guard shouldCommit(id, token: token) else { return false }
        tokens[id] = nil
        return true
    }
}
