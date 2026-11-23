import AppKit
import Combine
import NotchpadCore
import SwiftUI

/// Places the panel over the notch of the built-in screen and opens/closes it.
@MainActor
final class NotchWindowController {
    private let model: AppModel
    private var machine = PanelStateMachine()
    private let monitors = MouseMonitors()
    private var panel: NotchPanel?
    private var tickTimer: Timer?
    private var notch: CGRect = .zero
    private var openRect: CGRect = .zero
    /// The app that was in front before edit mode took focus; it gets focus back on Done.
    private var frontAppBeforeEdit: NSRunningApplication?
    private lazy var gallery = GalleryWindowController(model: model)
    private var galleryWatch: AnyCancellable?

    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    init(model: AppModel, forceOpen: Bool) {
        self.model = model
        machine.forceOpen = forceOpen
    }

    func start() {
        model.onShelfDragActive = { [weak self] active in
            guard let self else { return }
            self.machine.setShelfDragActive(active, now: ProcessInfo.processInfo.systemUptime)
            self.sync()
        }
        model.onEditingChanged = { [weak self] on in self?.setEditing(on) }
        galleryWatch = model.$showGallery.removeDuplicates().sink { [weak self] show in
            DispatchQueue.main.async { self?.setGalleryVisible(show) }
        }
        monitors.onMouseMoved = { [weak self] point in self?.mouseMoved(to: point) }
        monitors.onFileDragMoved = { [weak self] point in self?.fileDragMoved(to: point) }
        monitors.start()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }
        layout()
        sync()
    }

    /// The built-in display, if it's connected and awake.
    private static func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
    }

    private func layout() {
        guard let screen = Self.builtInScreen(),
              let notchRect = NotchGeometry.notchRect(ScreenMetrics(
                  frame: screen.frame,
                  leftAuxWidth: screen.auxiliaryTopLeftArea?.width,
                  rightAuxWidth: screen.auxiliaryTopRightArea?.width,
                  safeTop: screen.safeAreaInsets.top))
        else {
            panel?.orderOut(nil)
            return
        }
        notch = notchRect
        openRect = NotchGeometry.openRect(notch: notchRect, screen: screen.frame)
        model.notchSize = notchRect.size

        if panel == nil {
            let p = NotchPanel(frame: openRect)
            let host = PanelHostingView(rootView: NotchRootView(model: model))
            host.shelf = model.shelf
            host.isEditing = { [weak model] in model?.isEditing ?? false }
            host.onEditWidgets = { [weak model] in
                guard let model else { return }
                if model.isEditing { model.endEditing() } else { model.beginEditing() }
            }
            host.frame = NSRect(origin: .zero, size: openRect.size)
            p.contentView = host
            panel = p
        }
        panel?.setFrame(openRect, display: true)
        panel?.orderFrontRegardless()
    }

    /// Edit mode holds the panel open and lets it take typing; Done hands focus back.
    private func setEditing(_ on: Bool) {
        machine.setEditing(on, now: ProcessInfo.processInfo.systemUptime)
        if on {
            let front = NSWorkspace.shared.frontmostApplication
            if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { frontAppBeforeEdit = front }
            panel?.allowsKey = true
            NSApp.activate(ignoringOtherApps: true)
            panel?.makeKey()
        } else {
            panel?.allowsKey = false
            panel?.resignKey()
            // Only if Notchpad still has focus: if he switched to another app meanwhile, leave it there.
            if NSApp.isActive { frontAppBeforeEdit?.activate() }
            frontAppBeforeEdit = nil
        }
        sync()
    }

    private func setGalleryVisible(_ show: Bool) {
        if show, model.isEditing {
            let level = NSWindow.Level(rawValue: (panel?.level.rawValue ?? NSWindow.Level.floating.rawValue) - 1)
            gallery.show(below: openRect, level: level)
        } else {
            gallery.close()
            if model.isEditing { panel?.makeKey() }
        }
    }

    /// For `--snapshot-gallery`: the gallery's content view.
    var galleryContentView: NSView? { gallery.contentView }

    /// For `--snapshot`: the panel's content view.
    var contentView: NSView? { panel?.contentView }

    private func mouseMoved(to point: CGPoint) {
        let width = model.stripWidth
        let wing = width > 0 ? NotchGeometry.wingRect(notch: notch, width: width) : nil
        let zone = machine.isOpen ? openRect : NotchGeometry.hotZone(notch: notch, wing: wing)
        machine.pointer(inside: zone.contains(point), now: ProcessInfo.processInfo.systemUptime)
        sync()
    }

    /// A file drag coming within 40 pt below the hot zone opens the panel straight away.
    private func fileDragMoved(to point: CGPoint) {
        guard !machine.isOpen else { return }
        var zone = NotchGeometry.hotZone(notch: notch)
        zone.origin.y -= 40
        zone.size.height += 40
        if zone.contains(point) {
            machine.fileDragNearNotch(now: ProcessInfo.processInfo.systemUptime)
            sync()
        }
    }

    /// Applies the state machine's decision to the window and model, and runs the
    /// 50 ms tick only while a delayed open or close is waiting.
    private func sync() {
        if machine.isOpen != model.isOpen {
            let open = machine.isOpen
            panel?.ignoresMouseEvents = !open
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { model.isOpen = open }
            DebugTools.log(open ? "open" : "closed")
            if open { model.panelDidOpen(); onOpen?() } else { model.panelDidClose(); onClose?() }
        }
        if machine.hasPendingDeadline {
            guard tickTimer == nil else { return }
            tickTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.machine.tick(now: ProcessInfo.processInfo.systemUptime)
                    self.sync()
                }
            }
        } else {
            tickTimer?.invalidate()
            tickTimer = nil
        }
    }
}

/// Hosting view that shows the panel menu on right-click.
final class PanelHostingView<Content: View>: NSHostingView<Content> {
    weak var shelf: ShelfStore?
    var isEditing: () -> Bool = { false }
    var onEditWidgets: () -> Void = {}

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(PanelMenu.make(shelf: shelf, editing: isEditing(), onEditWidgets: onEditWidgets),
                                with: event, for: self)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
