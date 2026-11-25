import Foundation
import Testing
@testable import NotchpadCore

@Test func volumeSymbolFollowsLevelAndMute() {
    #expect(VolumeLevel(volume: 0.8, muted: true).symbolName == "speaker.slash.fill")
    #expect(VolumeLevel(volume: 0, muted: false).symbolName == "speaker.slash.fill")
    #expect(VolumeLevel(volume: 0.2, muted: false).symbolName == "speaker.wave.1.fill")
    #expect(VolumeLevel(volume: 0.5, muted: false).symbolName == "speaker.wave.2.fill")
    #expect(VolumeLevel(volume: 0.9, muted: false).symbolName == "speaker.wave.3.fill")
}

@Test func mutedBarShowsEmpty() {
    #expect(VolumeLevel(volume: 0.7, muted: true).shownFraction == 0)
    #expect(VolumeLevel(volume: 0.7, muted: false).shownFraction == 0.7)
}

@Test func draggingSetsVolumeAndUnmutes() {
    let muted = VolumeLevel(volume: 0.4, muted: true)
    #expect(muted.setting(0.6) == VolumeLevel(volume: 0.6, muted: false))
    // Dragging to zero doesn't unmute; it is silent either way.
    #expect(muted.setting(0) == VolumeLevel(volume: 0, muted: true))
    // Out-of-range values are clamped.
    #expect(VolumeLevel(volume: 0.5, muted: false).setting(1.4).volume == 1)
    #expect(VolumeLevel(volume: 0.5, muted: false).setting(-0.2).volume == 0)
}

@Test func speakerClickTogglesMute() {
    #expect(VolumeLevel(volume: 0.5, muted: false).toggledMute() == VolumeLevel(volume: 0.5, muted: true))
    #expect(VolumeLevel(volume: 0.5, muted: true).toggledMute() == VolumeLevel(volume: 0.5, muted: false))
    // Unmuting at zero would still be silent, so it comes back at a quarter.
    #expect(VolumeLevel(volume: 0, muted: true).toggledMute() == VolumeLevel(volume: 0.25, muted: false))
    #expect(VolumeLevel(volume: 0, muted: false).toggledMute() == VolumeLevel(volume: 0.25, muted: false))
}

@Test func unavailableOutputCannotChange() {
    let fixed = VolumeLevel.unavailable
    #expect(!fixed.settable)
    #expect(fixed.setting(0.8) == fixed)
    #expect(fixed.toggledMute() == fixed)
}

@Test func verticalBarFractionCountsFromTheBottom() {
    #expect(VolumeLevel.fraction(y: 0, height: 50) == 1)
    #expect(VolumeLevel.fraction(y: 50, height: 50) == 0)
    #expect(VolumeLevel.fraction(y: 25, height: 50) == 0.5)
    #expect(VolumeLevel.fraction(y: -10, height: 50) == 1)
    #expect(VolumeLevel.fraction(y: 80, height: 50) == 0)
    #expect(VolumeLevel.fraction(y: 10, height: 0) == 0)
}
