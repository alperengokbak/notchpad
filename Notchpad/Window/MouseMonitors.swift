import AppKit

/// Watches the mouse everywhere (global) and over our own panel (local).
/// Mouse-event monitoring needs no special permission.
@MainActor
final class MouseMonitors {
    var onMouseMoved: ((CGPoint) -> Void)?
    /// Called while a file is being dragged anywhere on screen (from Finder or any app).
    var onFileDragMoved: ((CGPoint) -> Void)?
    /// Trackpad and mouse-wheel scrolls anywhere (for the swipe-to-change-songs gesture).
    var onScroll: ((NSEvent) -> Void)?

    private var tokens: [Any] = []
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var changeCountAtMouseDown = 0
    private var isFileDrag = false

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.onMouseMoved?(NSEvent.mouseLocation) }
        }) { tokens.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.onMouseMoved?(NSEvent.mouseLocation) }
            return event
        }) { tokens.append(l) }

        if let g = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.onScroll?(event) }
        }) { tokens.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.onScroll?(event) }
            return event
        }) { tokens.append(l) }

        // A drag that started a new drag pasteboard with file URLs on it is a file drag.
        if let down = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp], handler: { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isFileDrag = false
                if event.type == .leftMouseDown { self.changeCountAtMouseDown = self.dragPasteboard.changeCount }
            }
        }) { tokens.append(down) }
        if let drag = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.isFileDrag, self.dragPasteboard.changeCount != self.changeCountAtMouseDown,
                   self.dragPasteboard.types?.contains(.fileURL) == true {
                    self.isFileDrag = true
                }
                if self.isFileDrag { self.onFileDragMoved?(NSEvent.mouseLocation) }
            }
        }) { tokens.append(drag) }
    }

    func stop() {
        tokens.forEach(NSEvent.removeMonitor)
        tokens.removeAll()
    }
}
