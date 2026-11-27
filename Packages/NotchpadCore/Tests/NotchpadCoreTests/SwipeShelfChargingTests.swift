import Foundation
import Testing
@testable import NotchpadCore

// MARK: Swipe

/// Feeds one two-finger swipe: began, a few changed steps, ended.
private func swipe(_ d: inout SwipeDetector, fingerDX: Double, dy: Double = 0, inverted: Bool, steps: Int = 5) -> [SwipeAction] {
    // With natural scrolling (inverted) the reported delta follows the fingers; without it, it's reversed.
    let dx = inverted ? fingerDX : -fingerDX
    var out: [SwipeAction] = []
    if let a = d.feed(dx: 0, dy: 0, phase: .began, momentum: false, inverted: inverted) { out.append(a) }
    for _ in 0..<steps {
        if let a = d.feed(dx: dx / Double(steps), dy: dy / Double(steps), phase: .changed, momentum: false, inverted: inverted) { out.append(a) }
    }
    if let a = d.feed(dx: 0, dy: 0, phase: .ended, momentum: false, inverted: inverted) { out.append(a) }
    return out
}

@Test func swipeLeftIsNextRightIsPrevious() {
    var d = SwipeDetector()
    #expect(swipe(&d, fingerDX: -120, inverted: true) == [.next])
    #expect(swipe(&d, fingerDX: 120, inverted: true) == [.previous])
    // Same finger movement with natural scrolling switched off.
    #expect(swipe(&d, fingerDX: -120, inverted: false) == [.next])
    #expect(swipe(&d, fingerDX: 120, inverted: false) == [.previous])
}

@Test func smallOrVerticalMovesDoNothing() {
    var d = SwipeDetector()
    #expect(swipe(&d, fingerDX: -20, inverted: true).isEmpty)          // too short
    #expect(swipe(&d, fingerDX: -80, dy: 150, inverted: true).isEmpty) // mostly vertical (scrolling a list)
}

@Test func oneSwipeFiresOnceAndMomentumIsIgnored() {
    var d = SwipeDetector()
    #expect(swipe(&d, fingerDX: -400, inverted: true, steps: 20) == [.next])
    // Coasting after the fingers lift must not start another skip.
    #expect(d.feed(dx: -300, dy: 0, phase: .other, momentum: true, inverted: true) == nil)
}

// MARK: Shelf order and settings

@Test func shelfNewestFirstReversesAddOrder() {
    let items = ["a", "b", "c"]
    #expect(ShelfOrder.arrange(items, newestFirst: false) == ["a", "b", "c"])
    #expect(ShelfOrder.arrange(items, newestFirst: true) == ["c", "b", "a"])
}

@Test func newPreferencesDefaults() {
    let suite = "notchpad-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    #expect(prefs.swipeToChangeSongs)
    #expect(!prefs.shelfNewestFirst)
    #expect(prefs.openOnFileDrag)
    #expect(prefs.showChargingAnimation)
    prefs.swipeToChangeSongs = false
    prefs.shelfNewestFirst = true
    prefs.openOnFileDrag = false
    prefs.showChargingAnimation = false
    let again = Preferences(defaults: defaults)
    #expect(!again.swipeToChangeSongs && again.shelfNewestFirst && !again.openOnFileDrag && !again.showChargingAnimation)
}

// MARK: Charging

@Test func chargingShowsOnlyWhenPluggedIn() {
    let off = PowerState(onAC: false, percent: 64)
    let on = PowerState(onAC: true, percent: 64)
    #expect(PowerState.justPluggedIn(previous: off, current: on))
    #expect(!PowerState.justPluggedIn(previous: on, current: on))   // already plugged in
    #expect(!PowerState.justPluggedIn(previous: on, current: off))  // unplugged
    #expect(!PowerState.justPluggedIn(previous: nil, current: on))  // first reading at launch
}

@Test func chargingWingGoesRight() {
    #expect(NotchGeometry.wings(focus: false, mic: false, music: false, charging: true) == WingWidths(left: 0, right: 70))
    #expect(NotchGeometry.wings(focus: true, mic: false, music: true, charging: true) == WingWidths(left: 106, right: 106))
    #expect(NotchGeometry.wings(focus: true, mic: false, music: true) == WingWidths(left: 106, right: 36))
}

@Test func mirrorWidgetInCatalog() {
    #expect(WidgetKind.mirror.title == "Mirror")
    #expect(WidgetKind.mirror.category == .media)
    #expect(WidgetKind.mirror.sizes == [.small, .medium, .wide])
    #expect(WidgetKind.mirror.dataSources.isEmpty) // the camera starts only on a click
}

@Test func shelfOrderPutsPinnedFirst() {
    func item(_ n: String, _ pinned: Bool) -> ShelfItem {
        ShelfItem(id: UUID(), bookmark: Data(), name: n, pinned: pinned)
    }
    let items = [item("a", false), item("cv", true), item("b", false), item("letter", true)]
    #expect(ShelfOrder.arrange(shelf: items, newestFirst: false).map(\.name) == ["cv", "letter", "a", "b"])
    #expect(ShelfOrder.arrange(shelf: items, newestFirst: true).map(\.name) == ["letter", "cv", "b", "a"])
}
