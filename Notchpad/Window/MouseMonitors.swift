import AppKit

/// Watches the mouse everywhere (global) and over our own panel (local).
/// Mouse-event monitoring needs no special permission.
@MainActor
final class MouseMonitors {
    var onMouseMoved: ((CGPoint) -> Void)?

    private var tokens: [Any] = []

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
    }

    func stop() {
        tokens.forEach(NSEvent.removeMonitor)
        tokens.removeAll()
    }
}
