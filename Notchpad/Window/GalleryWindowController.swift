import AppKit
import SwiftUI

/// Floating, key-capable panel that holds the widget gallery, placed under the open notch panel.
final class GalleryPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc closes the gallery.
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

@MainActor
final class GalleryWindowController {
    static let size = CGSize(width: 700, height: 420)
    private let model: AppModel
    private var panel: GalleryPanel?

    init(model: AppModel) {
        self.model = model
    }

    var contentView: NSView? { panel?.contentView }

    func show(below panelFrame: CGRect, level: NSWindow.Level) {
        let p = panel ?? makePanel()
        panel = p
        var origin = CGPoint(x: panelFrame.midX - Self.size.width / 2, y: panelFrame.minY - 8 - Self.size.height)
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(panelFrame) }) {
            let v = screen.visibleFrame
            origin.x = min(max(origin.x, v.minX + 8), v.maxX - Self.size.width - 8)
            origin.y = max(origin.y, v.minY + 8)
        }
        p.level = level
        p.setFrame(CGRect(origin: origin, size: Self.size), display: true)
        p.makeKeyAndOrderFront(nil)
        DebugTools.log("gallery: open")
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        DebugTools.log("gallery: closed")
    }

    private func makePanel() -> GalleryPanel {
        let p = GalleryPanel(contentRect: CGRect(origin: .zero, size: Self.size),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.onCancel = { [weak model] in model?.showGallery = false }
        let host = NSHostingView(rootView: GalleryView(model: model))
        host.frame = CGRect(origin: .zero, size: Self.size)
        p.contentView = host
        return p
    }
}
