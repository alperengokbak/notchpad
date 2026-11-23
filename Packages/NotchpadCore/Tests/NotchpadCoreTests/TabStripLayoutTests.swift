import Foundation
import Testing
@testable import NotchpadCore

// Real numbers: 680 pt panel, 185 pt notch, edit-mode buttons start at x 515.
private let sides = (leftStart: CGFloat(22), leftEnd: CGFloat(237.5), rightStart: CGFloat(442.5), rightEnd: CGFloat(509))

private func place(_ widths: [CGFloat], plus: CGFloat = 0) -> TabStripSlots {
    TabStripLayout.place(widths: widths, leftStart: sides.leftStart, leftEnd: sides.leftEnd,
                         rightStart: sides.rightStart, rightEnd: sides.rightEnd, plusWidth: plus, spacing: 6)
}

/// Every pill (and the + button) sits fully inside the left or the right strip, without overlaps.
private func allInside(_ s: TabStripSlots, plus: CGFloat) -> Bool {
    var items = zip(s.mids, s.widths).map { ($0 - $1 / 2, $0 + $1 / 2) }
    if let p = s.plusMid { items.append((p - plus / 2, p + plus / 2)) }
    let inside = items.allSatisfy { (a, b) in
        (a >= sides.leftStart - 0.01 && b <= sides.leftEnd + 0.01) || (a >= sides.rightStart - 0.01 && b <= sides.rightEnd + 0.01)
    }
    let sorted = items.sorted { $0.0 < $1.0 }
    let noOverlap = zip(sorted, sorted.dropFirst()).allSatisfy { $0.1 <= $1.0 + 0.01 }
    return inside && noOverlap
}

@Test func shortTabsStayLeftAtFullWidth() {
    let s = place([51, 77, 66], plus: 22)
    #expect(s.widths == [51, 77, 66])
    #expect(s.mids.allSatisfy { $0 < sides.leftEnd })
    #expect(allInside(s, plus: 22))
}

@Test func plusNeverRunsUnderTheEditButtons() {
    // "Study time", "Reminders", "Tailscale" after a rename: the + used to land at 515–537.
    let s = place([74, 77, 66], plus: 22)
    #expect(s.plusMid != nil)
    #expect(allInside(s, plus: 22))
}

@Test func fourLongTabsAllFit() {
    // "Productivity", "Networking", "Reminders", "Tailscale": the 4th used to sit under "Add widget".
    let s = place([88, 82, 77, 66])
    #expect(s.mids.count == 4)
    #expect(allInside(s, plus: 0))
}
