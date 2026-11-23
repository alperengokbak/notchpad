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
