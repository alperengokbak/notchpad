import Foundation

/// Where a widget's data comes from. A source only runs while a widget needing it is on screen.
public enum DataSource: Sendable {
    case music, reminders, calendar, tailscale
}

public enum WidgetCategory: String, CaseIterable, Sendable {
    case media, productivity, network

    public var title: String {
        switch self {
        case .media: "Media"
        case .productivity: "Productivity"
        case .network: "Network"
        }
    }
}

/// How much of the 3-column grid a widget covers.
public enum WidgetSize: String, Codable, CaseIterable, Sendable {
    case small, medium, wide, full

    /// Columns covered. Small also covers only half the height.
    public var columns: Int {
        switch self {
        case .small, .medium: 1
        case .wide: 2
        case .full: 3
        }
    }

    public var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .wide: "Wide"
        case .full: "Full"
        }
    }
}

/// Every widget Notchpad can show.
public enum WidgetKind: String, Codable, CaseIterable, Sendable {
    case music, shelf, reminders, nextEvent, focus, tailscale, launcher, mirror

    public var title: String {
        switch self {
        case .music: "Music"
        case .shelf: "Shelf"
        case .reminders: "Reminders"
        case .nextEvent: "Next event"
        case .focus: "Focus"
        case .tailscale: "Tailscale"
        case .launcher: "Shortcuts"
        case .mirror: "Mirror"
        }
    }

    /// SF Symbol for the gallery.
    public var symbol: String {
        switch self {
        case .music: "music.note"
        case .shelf: "tray.full"
        case .reminders: "checklist"
        case .nextEvent: "calendar"
        case .focus: "timer"
        case .tailscale: "network"
        case .launcher: "square.grid.2x2.fill"
        case .mirror: "person.crop.square"
        }
    }

    public var category: WidgetCategory {
        switch self {
        case .music, .shelf, .mirror: .media
        case .reminders, .nextEvent, .focus, .launcher: .productivity
        case .tailscale: .network
        }
    }

    /// Supported sizes, smallest first.
    public var sizes: [WidgetSize] {
        switch self {
        case .music: [.small, .medium]
        case .shelf: [.small, .medium, .wide]
        case .reminders: [.medium, .wide, .full]
        case .nextEvent: [.small, .medium]
        case .focus: [.small]
        case .tailscale: [.medium, .full]
        case .launcher: [.small, .medium, .wide]
        case .mirror: [.small, .medium, .wide]
        }
    }

    public var dataSources: Set<DataSource> {
        switch self {
        case .music: [.music]
        case .reminders: [.reminders]
        case .nextEvent: [.calendar]
        case .tailscale: [.tailscale]
        case .shelf, .focus, .launcher, .mirror: []
        }
    }
}

/// Top or bottom half of a column (Small widgets), or the whole height (everything else).
public enum SlotHalf: String, Codable, Sendable {
    case top, bottom, full
}

/// One widget placed on a tab.
public struct WidgetPlacement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: WidgetKind
    public var size: WidgetSize
    public var column: Int
    public var half: SlotHalf

    public init(id: UUID = UUID(), kind: WidgetKind, size: WidgetSize, column: Int, half: SlotHalf) {
        self.id = id
        self.kind = kind
        self.size = size
        self.column = column
        self.half = half
    }
}
