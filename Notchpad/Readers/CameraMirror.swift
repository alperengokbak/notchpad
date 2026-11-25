@preconcurrency import AVFoundation
import AppKit
import SwiftUI

/// The Mirror widget's camera. Runs only after a click on the widget, and stops when the panel
/// closes or the widget leaves the screen, so the camera light never comes on by surprise.
/// Every start sets the camera up fresh (whichever camera is there now, the built-in one first),
/// so a call app (Teams, Zoom…) taking or switching the camera can't leave it stuck.
@MainActor
final class CameraMirror: ObservableObject {
    enum State: Equatable { case off, starting, running, denied, noCamera, busy }

    @Published private(set) var state: State = .off
    /// Rebuilt on every start.
    @Published private(set) var session = AVCaptureSession()
    private let queue = DispatchQueue(label: "notchpad.camera")
    private var observers: [NSObjectProtocol] = []
    private var attempt = 0

    func start() {
        DebugTools.log("mirror: start pressed, state \(state), permission \(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
        guard state != .running, state != .starting else { return }
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
                    if self.state == .starting { self.run() }
                }
            }
        default:
            state = .denied
        }
    }

    /// `--editor mirror-busy`: shows the busy message for a screenshot.
    func showBusyForDebug() { state = .busy }

    func stop() {
        guard state == .running || state == .starting || state == .busy else { return }
        attempt += 1
        state = .off
        tearDown()
        DebugTools.log("mirror: off")
    }

    /// The built-in camera if there is one, otherwise any camera (USB, Continuity Camera).
    private static func pickCamera() -> AVCaptureDevice? {
        let found = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                                     mediaType: .video, position: .unspecified).devices
        return found.first { $0.deviceType == .builtInWideAngleCamera } ?? found.first ?? AVCaptureDevice.default(for: .video)
    }

    private func run() {
        tearDown()
        guard let device = Self.pickCamera() else { state = .noCamera; return }
        let fresh = AVCaptureSession()
        guard let input = try? AVCaptureDeviceInput(device: device), fresh.canAddInput(input) else {
            state = .busy
            DebugTools.log("mirror: camera can't be opened (in use elsewhere: \(device.isInUseByAnotherApplication))")
            return
        }
        fresh.beginConfiguration()
        fresh.sessionPreset = .medium
        fresh.addInput(input)
        fresh.commitConfiguration()
        session = fresh
        watch(fresh, device: device)
        state = .starting
        attempt += 1
        let mine = attempt
        queue.async {
            fresh.startRunning()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.attempt == mine, self.state == .starting else { fresh.stopRunning(); return }
                self.state = fresh.isRunning ? .running : .busy
                DebugTools.log("mirror: \(self.state) (\(device.localizedName))")
            }
        }
        // A camera that never starts (held by another app) shows "busy" instead of spinning forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            guard let self, self.attempt == mine, self.state == .starting else { return }
            self.state = .busy
            DebugTools.log("mirror: start timed out")
        }
    }

    /// Another app stopping the camera, an error, or the camera going away: show "busy" (click to retry).
    private func watch(_ session: AVCaptureSession, device: AVCaptureDevice) {
        let center = NotificationCenter.default
        let interrupted: (Notification) -> Void = { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, self.session === session, self.state == .running else { return }
                self.state = .busy
                DebugTools.log("mirror: interrupted (\(note.name.rawValue))")
            }
        }
        observers = [
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main, using: interrupted),
            center.addObserver(forName: AVCaptureSession.didStopRunningNotification, object: session, queue: .main, using: interrupted),
            center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: device, queue: .main, using: interrupted),
        ]
    }

    private func tearDown() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        let old = session
        queue.async { if old.isRunning { old.stopRunning() } }
    }
}

/// The live picture, flipped like a mirror (unless "Flip image" is on) and cropped to fill the widget.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var mirrored = true

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView(session: session)
        view.mirrored = mirrored
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) { view.mirrored = mirrored }

    final class PreviewView: NSView {
        private let preview: AVCaptureVideoPreviewLayer
        var mirrored = true { didSet { if mirrored != oldValue { fitPreview() } } }

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
            if let connection = preview.connection, connection.isVideoMirroringSupported, connection.isVideoMirrored != mirrored {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
            DebugTools.log("mirror: preview \(Int(bounds.width))x\(Int(bounds.height)), connection \(preview.connection != nil)")
        }

        /// Clicks go through to the widget (so a click turns the camera off again).
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
