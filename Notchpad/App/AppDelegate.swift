import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
}
