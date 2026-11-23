import Foundation
import Testing
@testable import NotchpadCore

private func place(_ kind: WidgetKind, _ size: WidgetSize, _ column: Int, _ half: SlotHalf) -> WidgetPlacement {
    WidgetPlacement(id: UUID(), kind: kind, size: size, column: column, half: half)
}

private func close(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.01 }

@Test func catalogSizes() {
    #expect(WidgetKind.focus.sizes == [.small])
    #expect(WidgetKind.reminders.sizes == [.medium, .wide, .full])
    #expect(WidgetKind.tailscale.sizes == [.medium, .full])
    #expect(WidgetKind.music.sizes == [.small, .medium])
    #expect(WidgetKind.shelf.sizes == [.small, .medium, .wide])
    #expect(WidgetKind.nextEvent.sizes == [.small, .medium])
    #expect(WidgetKind.shelf.dataSources.isEmpty)
    #expect(WidgetKind.nextEvent.dataSources == [.calendar])
}

@Test func cellsForEachSize() {
    #expect(WidgetGrid.cells(size: .small, column: 1, half: .bottom) == [GridCell(column: 1, row: 1)])
    #expect(WidgetGrid.cells(size: .wide, column: 1, half: .full) == [
        GridCell(column: 1, row: 0), GridCell(column: 1, row: 1),
        GridCell(column: 2, row: 0), GridCell(column: 2, row: 1),
    ])
    #expect(WidgetGrid.cells(size: .full, column: 0, half: .full)?.count == 6)
    #expect(WidgetGrid.cells(size: .full, column: 1, half: .full) == nil)
    #expect(WidgetGrid.cells(size: .wide, column: 2, half: .full) == nil)
    #expect(WidgetGrid.cells(size: .small, column: 0, half: .full) == nil)
    #expect(WidgetGrid.cells(size: .medium, column: 0, half: .top) == nil)
}

@Test func fitsDetectsOverlap() {
    let reminders = place(.reminders, .medium, 1, .full)
    #expect(!WidgetGrid.fits(size: .small, column: 1, half: .top, among: [reminders]))
    #expect(WidgetGrid.fits(size: .small, column: 2, half: .top, among: [reminders]))
    #expect(WidgetGrid.fits(size: .small, column: 1, half: .top, among: [reminders], ignoring: reminders.id))
}

@Test func firstFreeSpotFillsTopThenBottom() {
    let music = place(.music, .small, 0, .top)
    let shelf = place(.shelf, .small, 0, .bottom)
    #expect(WidgetGrid.firstFreeSpot(for: .small, among: [music])! == (0, .bottom))
    #expect(WidgetGrid.firstFreeSpot(for: .medium, among: [music, shelf])! == (1, .full))
    let home = [music, shelf, place(.reminders, .medium, 1, .full),
                place(.nextEvent, .small, 2, .top), place(.focus, .small, 2, .bottom)]
    #expect(WidgetGrid.firstFreeSpot(for: .small, among: home) == nil)
    #expect(WidgetGrid.firstFreeSpot(for: .full, among: [])! == (0, .full))
    #expect(WidgetGrid.firstFreeSpot(for: .full, among: [music]) == nil)
}

@Test func frameMath() {
    let area = CGSize(width: 636, height: 146)
    let small = WidgetGrid.frame(size: .small, column: 0, half: .top, in: area, gap: 10)
    #expect(close(small.minX, 0) && close(small.minY, 0))
    #expect(close(small.width, 205.333) && close(small.height, 68))
    let bottom = WidgetGrid.frame(size: .small, column: 0, half: .bottom, in: area, gap: 10)
    #expect(close(bottom.minY, 78))
    let wide = WidgetGrid.frame(size: .wide, column: 1, half: .full, in: area, gap: 10)
    #expect(close(wide.minX, 215.333) && close(wide.width, 420.667) && close(wide.height, 146))
}

@Test func cellAtPoint() {
    let area = CGSize(width: 636, height: 146)
    #expect(WidgetGrid.cell(at: CGPoint(x: 10, y: 10), in: area) == GridCell(column: 0, row: 0))
    #expect(WidgetGrid.cell(at: CGPoint(x: 630, y: 140), in: area) == GridCell(column: 2, row: 1))
    #expect(WidgetGrid.cell(at: CGPoint(x: -1, y: 5), in: area) == nil)
    #expect(WidgetGrid.cell(at: CGPoint(x: 700, y: 5), in: area) == nil)
}
