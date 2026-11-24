import AppKit
import SwiftUI

/// Mirror widget: click to see yourself (before a call), click again or close the panel to stop.
struct MirrorView: View {
    @ObservedObject var camera: CameraMirror
    /// Gallery previews and demo screenshots: a drawn placeholder, never the real camera.
    var demoImage: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.1))
            if let demoImage {
                Image(nsImage: demoImage).resizable().aspectRatio(contentMode: .fill)
            } else if camera.state == .running {
                CameraPreview(session: camera.session)
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            guard demoImage == nil else { return }
            if camera.state == .running { camera.stop() } else { camera.start() }
        }
        .help(camera.state == .running ? "Click to turn the camera off" : "Click to check how you look")
    }

    @ViewBuilder private var placeholder: some View {
        VStack(spacing: 6) {
            switch camera.state {
            case .denied:
                Image(systemName: "video.slash").font(.system(size: 18)).foregroundStyle(Color(white: 0.5))
                Text("Camera access is off").font(.system(size: 11)).foregroundStyle(Color(white: 0.6))
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                }
                .buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
            case .noCamera:
                Image(systemName: "video.slash").font(.system(size: 18)).foregroundStyle(Color(white: 0.5))
                Text("No camera found").font(.system(size: 11)).foregroundStyle(Color(white: 0.6))
            case .starting:
                ProgressView().controlSize(.small)
            default:
                Image(systemName: "person.crop.square").font(.system(size: 22)).foregroundStyle(Color(white: 0.55))
                Text("Mirror").font(.system(size: 12, weight: .semibold))
                Text("Click to check how you look").font(.system(size: 10)).foregroundStyle(Color(white: 0.55))
            }
        }
        .multilineTextAlignment(.center)
        .padding(8)
    }
}

/// Closed notch: the charger was just plugged in. A green bolt and the battery level, for a few seconds.
struct ChargingWing: View {
    let percent: Int?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.green)
                .symbolEffect(.pulse)
            if let percent {
                Text("\(percent)%").font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
        }
    }
}
