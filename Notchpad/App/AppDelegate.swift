import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var windowController: NotchWindowController?

    private var sheetWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let path = DebugTools.argument(after: "--widget-sheet") {
            renderWidgetSheet(to: path)
            return
        }
        let forceOpen = CommandLine.arguments.contains("--force-open")
        let controller = NotchWindowController(model: model, forceOpen: forceOpen)
        controller.start()
        windowController = controller
        if let path = DebugTools.argument(after: "--snapshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let view = controller.contentView { DebugTools.snapshot(view, to: path) }
                NSApp.terminate(nil)
            }
        }
    }

    /// Renders `WidgetSheet` off screen, saves it and quits.
    private func renderWidgetSheet(to path: String) {
        let host = NSHostingView(rootView: WidgetSheet(inputs: DemoData.inputs(now: Date())))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: host.frame.width, height: host.frame.height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        sheetWindow = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            DebugTools.snapshot(host, to: path)
            NSApp.terminate(nil)
        }
    }
}
