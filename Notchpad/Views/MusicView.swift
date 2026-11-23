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
    /// "Music" or "Spotify".
    var appName = "Music"
    /// Medium size: larger artwork, progress and controls under it across the full width.
    var large = false

    private var track: NowPlaying? { if case .playing(let n) = state { n } else { nil } }

    var body: some View {
        if large {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    cover
                    titles
                }
                progress
                controls.frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                cover
                VStack(alignment: .leading, spacing: 2) {
                    titles
                    progress.padding(.top, 4)
                    controls.padding(.top, 2)
                }
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
        let fraction: Double = {
            guard let track, let d = track.duration, d > 0 else { return 0 }
            return track.position(at: now) / d
        }()
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.2))
                Capsule().fill(Color.white).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
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
