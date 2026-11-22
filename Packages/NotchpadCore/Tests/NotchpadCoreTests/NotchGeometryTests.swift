import CoreGraphics
import Testing
@testable import NotchpadCore

private let metrics = ScreenMetrics(
    frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
    leftAuxWidth: 764, rightAuxWidth: 764, safeTop: 32
)
private let notch = CGRect(x: 764, y: 1085, width: 200, height: 32)

@Test func notchRectFromAuxAreas() {
    #expect(NotchGeometry.notchRect(metrics) == notch)
}

@Test func noNotchWhenSafeTopIsZero() {
    var m = metrics
    m.safeTop = 0
    #expect(NotchGeometry.notchRect(m) == nil)
}

@Test func noNotchWhenAuxAreasMissing() {
    var m = metrics
    m.leftAuxWidth = nil
    #expect(NotchGeometry.notchRect(m) == nil)
}

@Test func openRectIsCentredAndTopAligned() {
    #expect(NotchGeometry.openRect(notch: notch, screen: metrics.frame)
            == CGRect(x: 564, y: 917, width: 600, height: 200))
}

@Test func openRectIsClampedInsideScreen() {
    let leftNotch = CGRect(x: 10, y: 1085, width: 200, height: 32)
    #expect(NotchGeometry.openRect(notch: leftNotch, screen: metrics.frame).minX == 0)
}

@Test func hotZoneGrowsSidewaysAndDownOnly() {
    #expect(NotchGeometry.hotZone(notch: notch) == CGRect(x: 754, y: 1075, width: 220, height: 42))
}
