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
        DebugTools.log("mirror: start pressed, state \(state), permission \(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
        guard state == .off || state == .denied else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            state = .starting
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard granted else { self.state = .denied; return }
                    // Answering macOS's question usually closes the panel (stop() sets .off).
                    // Only start if the widget is still waiting; otherwise the next click starts it.
                    if self.state == .starting { self.run() }
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

    func makeNSView(context: Context) -> PreviewView { PreviewView(session: session) }
    func updateNSView(_ view: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        private let preview: AVCaptureVideoPreviewLayer

        init(session: AVCaptureSession) {
            preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            super.init(frame: .zero)
            wantsLayer = true
            layer?.addSublayer(preview)
        }

        required init?(coder: NSCoder) { nil }

        /// SwiftUI sizes this view by setting its frame (layout() isn't always called), so the
        /// picture follows every size change here.
        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            fitPreview()
        }

        override func layout() {
            super.layout()
            fitPreview()
        }

        private func fitPreview() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            preview.frame = bounds
            CATransaction.commit()
            if let connection = preview.connection, connection.isVideoMirroringSupported, !connection.isVideoMirrored {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
            DebugTools.log("mirror: preview \(Int(bounds.width))x\(Int(bounds.height)), connection \(preview.connection != nil)")
        }

        /// Clicks go through to the widget (so a click turns the camera off again).
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
