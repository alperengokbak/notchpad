import AppKit
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    /// The menu item. macOS sometimes needs him to approve login items in System Settings; say so
    /// instead of silently doing nothing (and offer to open the right page).
    @MainActor static func toggleWithFeedback() {
        let turningOn = !isEnabled
        var failure: String?
        do { try setEnabled(turningOn) } catch { failure = error.localizedDescription }
        let status = SMAppService.mainApp.status
        DebugTools.log("login item: \(status.rawValue)")
        guard turningOn, status == .requiresApproval || failure != nil else { return }
        let alert = NSAlert()
        alert.messageText = status == .requiresApproval ? "Approve Notchpad to start at login"
            : "Notchpad couldn't turn on Launch at login"
        alert.informativeText = status == .requiresApproval
            ? "macOS needs your OK. In System Settings → General → Login Items & Extensions, switch Notchpad on."
            : (failure ?? "")
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
    }
}
