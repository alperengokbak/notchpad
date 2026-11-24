@preconcurrency import AVFoundation
import AppKit
import SwiftUI

/// The Mirror widget's camera. Runs only after a click on the widget, and stops when the panel
/// closes or the widget leaves the screen, so the camera light never comes on by surprise.
@MainActor
final class CameraMirror: ObservableObject {
    enum State: Equatable { case off, starting, running, denied, noCamera }

    @Published private(set) var state: State = .off
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "notchpad.camera")
    private var configured = false

    func start() {
        guard state == .off || state == .denied else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            state = .starting
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if granted { self.run() } else { self.state = .denied }
                }
            }
        default:
            state = .denied
        }
    }

    func stop() {
        guard state == .running || state == .starting else { return }
        state = .off
        let session = session
        queue.async { session.stopRunning() }
        DebugTools.log("mirror: off")
    }

    private func run() {
        if !configured {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input)
            else { state = .noCamera; return }
            session.beginConfiguration()
            session.sessionPreset = .medium
            session.addInput(input)
            session.commitConfiguration()
            configured = true
        }
        state = .starting
        let session = session
        queue.async {
            session.startRunning()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.state == .starting else { session.stopRunning(); return }
                self.state = session.isRunning ? .running : .off
                DebugTools.log("mirror: \(self.state)")
            }
        }
    }
}

/// The live picture, flipped like a mirror and cropped to fill the widget.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer = layer
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
