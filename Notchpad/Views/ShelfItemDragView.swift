import AppKit
import SwiftUI

/// Makes its content draggable as a real file, and reports whether another app took it.
/// (SwiftUI's own drag doesn't say how the drag ended.)
struct ShelfItemDragView: NSViewRepresentable {
    let url: URL
    let onDragStarted: () -> Void
    let onDragEnded: (_ accepted: Bool) -> Void

    func makeNSView(context: Context) -> DragSourceView { DragSourceView() }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.url = url
        view.onDragStarted = onDragStarted
        view.onDragEnded = onDragEnded
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var url: URL?
    var onDragStarted: (() -> Void)?
    var onDragEnded: ((Bool) -> Void)?
    private var started = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { started = false }

    override func mouseDragged(with event: NSEvent) {
        guard !started, let url else { return }
        started = true
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 40, height: 40)
        let p = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(NSRect(x: p.x - 20, y: p.y - 20, width: 40, height: 40), contents: icon)
        onDragStarted?()
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        started = false
        onDragEnded?(operation != [])
    }
}
