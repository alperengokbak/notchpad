import AppKit
import NotchpadCore
import SwiftUI

/// Mini player for Apple Music or Spotify.
struct MusicView: View {
    let state: MusicState
    let artwork: NSImage?
    let now: Date
    let onCommand: (MusicCommand) -> Void
    let onOpenMusic: () -> Void
    /// Dragging the dot (or clicking the bar) jumps to that point of the song.
    var onSeek: (TimeInterval) -> Void = { _ in }
    /// "Music" or "Spotify".
    var appName = "Music"
    /// Medium size: larger artwork, progress and controls under it across the full width.
    var large = false
    /// The Mac's output volume. Medium: a bar under the song title. Small: a slim upright bar on the right.
    var volume = VolumeLevel(volume: 0.6, muted: false)
    var onSetVolume: (Double) -> Void = { _ in }
    var onToggleMute: () -> Void = {}

    private var track: NowPlaying? { if case .playing(let n) = state { n } else { nil } }

    var body: some View {
        if large {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    cover
                    VStack(alignment: .leading, spacing: 0) {
                        titles
                        Spacer(minLength: 6)
                        VolumeBar(level: volume, vertical: false, onSet: onSetVolume, onToggleMute: onToggleMute)
                    }
                    .frame(height: 76)
                }
                progress
                controls.frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                cover
                VStack(alignment: .leading, spacing: 2) {
                    titles
                    // The bar carries its own room around the dot, so no extra padding here.
                    progress
                    controls
                }
                VolumeBar(level: volume, vertical: true, onSet: onSetVolume, onToggleMute: onToggleMute)
                    .frame(width: 16, height: 64)
            }
        }
    }

    @ViewBuilder private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track?.title ?? "Not playing").font(.system(size: 13, weight: .semibold)).lineLimit(large ? 2 : 1)
            if let track {
                Text(track.artist).font(.system(size: 12)).foregroundStyle(Color(white: 0.6)).lineLimit(1)
            } else if state == .notRunning {
                Button("Open \(appName)", action: onOpenMusic).buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(white: 0.75))
            }
        }
    }

    private var cover: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(white: 0.25), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Image(systemName: "music.note").font(.system(size: 22)).foregroundStyle(Color(white: 0.45)))
            }
        }
        .frame(width: large ? 76 : 64, height: large ? 76 : 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progress: some View {
        let duration = track?.duration ?? 0
        let fraction = duration > 0 ? (track?.position(at: now) ?? 0) / duration : 0
        return ScrubBar(fraction: fraction, duration: duration, showTimes: large) { onSeek($0) }
    }

    private var controls: some View {
        let disabled = state == .notRunning
        return HStack(spacing: 18) {
            button("backward.fill", .previous)
            button(track?.isPlaying == true ? "pause.fill" : "play.fill", .playPause, size: 18)
            button("forward.fill", .next)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private func button(_ symbol: String, _ command: MusicCommand, size: CGFloat = 14) -> some View {
        Button { onCommand(command) } label: {
            Image(systemName: symbol).font(.system(size: size)).frame(width: 22, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The progress bar with a dot. Drag the dot, or click anywhere on the bar, to jump there.
/// The dot follows the pointer while dragging; the song moves when the drag ends.
struct ScrubBar: View {
    let fraction: Double
    /// Song length in seconds; 0 = unknown, then the bar can't be dragged.
    let duration: TimeInterval
    /// Elapsed and total time under the bar (Medium size).
    var showTimes = false
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    private var enabled: Bool { duration > 0 }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let f = min(max(dragFraction ?? fraction, 0), 1)
                let dot: CGFloat = dragFraction == nil ? 9 : 11
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.2)).frame(height: 4)
                    Capsule().fill(Color.white).frame(width: geo.size.width * f, height: 4)
                    if enabled {
                        Circle().fill(Color.white).frame(width: dot, height: dot)
                            .shadow(color: .black.opacity(0.4), radius: 1.5)
                            .offset(x: min(max(geo.size.width * f - dot / 2, 0), geo.size.width - dot))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { dragFraction = NowPlaying.seekFraction(x: $0.location.x, width: geo.size.width) }
                        .onEnded { value in
                            let f = NowPlaying.seekFraction(x: value.location.x, width: geo.size.width)
                            dragFraction = nil
                            onSeek(f * duration)
                        },
                    including: enabled ? .all : .none)
            }
            .frame(height: 10)
            if showTimes && enabled {
                HStack {
                    Text(Self.time((dragFraction ?? fraction) * duration))
                    Spacer()
                    Text(enabled ? Self.time(duration) : "")
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Color(white: 0.55))
            }
        }
    }

    static func time(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// The Mac's output volume: drag or click the bar to set it (the sound changes as you drag),
/// click the speaker to mute. Upright in the Small Music widget, across in the Medium one.
struct VolumeBar: View {
    let level: VolumeLevel
    let vertical: Bool
    let onSet: (Double) -> Void
    let onToggleMute: () -> Void

    @State private var dragFraction: Double?

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: 4) {
                    bar
                    speaker
                }
            } else {
                HStack(spacing: 8) {
                    speaker
                    bar
                }
            }
        }
        .disabled(!level.settable)
        .opacity(level.settable ? 1 : 0.35)
        .help(level.settable ? "Volume" : "This output can't change volume")
    }

    private var speaker: some View {
        Button(action: onToggleMute) {
            Image(systemName: level.symbolName)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.75))
                .frame(width: 16, height: 14, alignment: vertical ? .center : .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bar: some View {
        GeometryReader { geo in
            let length = vertical ? geo.size.height : geo.size.width
            let f = min(max(dragFraction ?? level.shownFraction, 0), 1)
            let dot: CGFloat = dragFraction == nil ? 8 : 10
            let filled = length * f
            let dotOffset = min(max(filled - dot / 2, 0), length - dot)
            ZStack(alignment: vertical ? .bottom : .leading) {
                Capsule().fill(Color(white: 0.2))
                    .frame(width: vertical ? 3 : nil, height: vertical ? nil : 3)
                Capsule().fill(Color(white: 0.85))
                    .frame(width: vertical ? 3 : filled, height: vertical ? filled : 3)
                if level.settable {
                    Circle().fill(Color.white).frame(width: dot, height: dot)
                        .shadow(color: .black.opacity(0.4), radius: 1.5)
                        .offset(x: vertical ? 0 : dotOffset, y: vertical ? -dotOffset : 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let f = fraction(value.location, geo.size)
                        dragFraction = f
                        onSet(f)
                    }
                    .onEnded { value in
                        onSet(fraction(value.location, geo.size))
                        dragFraction = nil
                    },
                including: level.settable ? .all : .none)
        }
        .frame(width: vertical ? 16 : nil, height: vertical ? nil : 10)
    }

    private func fraction(_ point: CGPoint, _ size: CGSize) -> Double {
        vertical ? VolumeLevel.fraction(y: point.y, height: size.height)
                 : NowPlaying.seekFraction(x: point.x, width: size.width)
    }
}
