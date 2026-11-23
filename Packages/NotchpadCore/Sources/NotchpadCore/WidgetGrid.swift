import Foundation

/// One half-column cell of the 3 x 2 grid. Row 0 is the top.
public struct GridCell: Hashable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

/// Geometry of a tab: 3 columns, each split into a top and bottom half.
public enum WidgetGrid {
    public static let columns = 3

    /// Cells covered by a widget, or nil when the spot is invalid for that size.
    public static func cells(size: WidgetSize, column: Int, half: SlotHalf) -> Set<GridCell>? {
        guard column >= 0, column + size.columns <= columns else { return nil }
        if size == .full, column != 0 { return nil }
        switch (size, half) {
        case (.small, .top): return [GridCell(column: column, row: 0)]
        case (.small, .bottom): return [GridCell(column: column, row: 1)]
        case (.small, .full), (_, .top), (_, .bottom): return nil
        default:
            var result = Set<GridCell>()
            for c in column..<(column + size.columns) {
                result.insert(GridCell(column: c, row: 0))
                result.insert(GridCell(column: c, row: 1))
            }
            return result
        }
    }

    public static func cells(of placement: WidgetPlacement) -> Set<GridCell>? {
        cells(size: placement.size, column: placement.column, half: placement.half)
    }

    public static func fits(size: WidgetSize, column: Int, half: SlotHalf,
                            among placements: [WidgetPlacement], ignoring: UUID? = nil) -> Bool {
        guard let wanted = cells(size: size, column: column, half: half) else { return false }
        let taken = placements.filter { $0.id != ignoring }.compactMap(cells(of:)).reduce(into: Set<GridCell>()) { $0.formUnion($1) }
        return wanted.isDisjoint(with: taken)
    }

    /// Left to right, top half before bottom half.
    public static func firstFreeSpot(for size: WidgetSize, among placements: [WidgetPlacement]) -> (column: Int, half: SlotHalf)? {
        let halves: [SlotHalf] = size == .small ? [.top, .bottom] : [.full]
        for column in 0..<columns {
            for half in halves where fits(size: size, column: column, half: half, among: placements) {
                return (column, half)
            }
        }
        return nil
    }

    /// Where a widget sits inside the content area (origin top-left).
    public static func frame(size: WidgetSize, column: Int, half: SlotHalf, in area: CGSize, gap: CGFloat) -> CGRect {
        let columnWidth = (area.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let halfHeight = (area.height - gap) / 2
        let x = CGFloat(column) * (columnWidth + gap)
        let width = CGFloat(size.columns) * columnWidth + CGFloat(size.columns - 1) * gap
        switch half {
        case .top: return CGRect(x: x, y: 0, width: width, height: halfHeight)
        case .bottom: return CGRect(x: x, y: halfHeight + gap, width: width, height: halfHeight)
        case .full: return CGRect(x: x, y: 0, width: width, height: area.height)
        }
    }

    /// The cell under a point in the content area, or nil outside it.
    public static func cell(at point: CGPoint, in area: CGSize) -> GridCell? {
        guard point.x >= 0, point.y >= 0, point.x < area.width, point.y < area.height else { return nil }
        let column = min(columns - 1, Int(point.x / (area.width / CGFloat(columns))))
        return GridCell(column: column, row: point.y < area.height / 2 ? 0 : 1)
    }
}
