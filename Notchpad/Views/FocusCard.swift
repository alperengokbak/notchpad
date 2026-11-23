import NotchpadCore
import SwiftUI

/// Right column, bottom: start 25/50, pause/stop while running, break/again when done.
struct FocusCard: View {
    let inputs: WidgetInputs
    private var focus: FocusTimer { inputs.focus }
    private var actions: WidgetActions { inputs.actions }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch focus.phase {
            case .idle:
                label("FOCUS", dot: nil)
                HStack(spacing: 6) {
                    pill("25") { actions.startFocus(.focus, 25) }
                    pill("50") { actions.startFocus(.focus, 50) }
                }
            case .running(let kind, _), .paused(let kind, _):
                label(kind == .focus ? "FOCUS" : "BREAK", dot: kind == .focus ? .red : .green)
                Text(FocusTimer.clock(focus.remaining(now: inputs.now) ?? 0))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .opacity(focus.isPaused ? 0.5 : 1)
                HStack(spacing: 14) {
                    icon(focus.isPaused ? "play.fill" : "pause.fill") { actions.togglePauseFocus() }
                    icon("stop.fill") { actions.stopFocus() }
                }
            case .done(let kind):
                HStack {
                    Text("Done").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    icon("xmark") { actions.stopFocus() }
                }
                HStack(spacing: 6) {
                    if kind == .focus { pill("5 min break") { actions.startFocus(.rest, 5) } }
                    pill("Again") { actions.startFocus(.focus, inputs.lastFocusMinutes) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ text: String, dot: Color?) -> some View {
        HStack(spacing: 5) {
            if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
            Text(text).font(.system(size: 10, weight: .medium)).tracking(0.6).foregroundStyle(Color(white: 0.55))
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color.white)).contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func icon(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13)).frame(width: 20, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Closed panel: the countdown on a black extension left of the notch.
struct FocusWing: View {
    let timer: FocusTimer
    let now: Date

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(timer.kind == .rest ? Color.green : Color.red).frame(width: 6, height: 6)
            Text(FocusTimer.clock(timer.remaining(now: now) ?? 0))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
        }
        .opacity(timer.isPaused ? 0.5 : 1)
    }
}

/// Closed panel: the microphone is in use, and for how long.
struct MicWing: View {
    let elapsed: TimeInterval

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "mic.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.red)
            Text(FocusTimer.clock(elapsed.rounded(.down)))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
        }
    }
}

/// Closed panel: the playing song's cover, left of the notch.
struct MusicCoverWing: View {
    let artwork: NSImage?

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.75))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.15))
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

/// Closed panel: four bars moving to the music, right of the notch. Only on screen while a song plays.
/// Core Animation runs the bars in the system's render server, so the app itself does no work per frame.
struct MusicBarsWing: NSViewRepresentable {
    func makeNSView(context: Context) -> BarsView { BarsView() }
    func updateNSView(_ view: BarsView, context: Context) {}

    final class BarsView: NSView {
        private static let durations: [CFTimeInterval] = [0.42, 0.31, 0.37, 0.27]
        private var bars: [CALayer] = []

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            for (i, duration) in Self.durations.enumerated() {
                let bar = CALayer()
                bar.backgroundColor = NSColor.white.cgColor
                bar.cornerRadius = 1.5
                let grow = CABasicAnimation(keyPath: "transform.scale.y")
                grow.fromValue = 0.3
                grow.toValue = 1
                grow.duration = duration
                grow.autoreverses = true
                grow.repeatCount = .infinity
                grow.timeOffset = Double(i) * 0.13
                grow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                bar.add(grow, forKey: "bounce")
                layer?.addSublayer(bar)
                bars.append(bar)
            }
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            let width: CGFloat = 3, gap: CGFloat = 2, height: CGFloat = 14
            let total = CGFloat(bars.count) * width + CGFloat(bars.count - 1) * gap
            var x = (bounds.width - total) / 2
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for bar in bars {
                bar.bounds = CGRect(x: 0, y: 0, width: width, height: height)
                bar.position = CGPoint(x: x + width / 2, y: bounds.midY)
                x += width + gap
            }
            CATransaction.commit()
        }
    }
}
