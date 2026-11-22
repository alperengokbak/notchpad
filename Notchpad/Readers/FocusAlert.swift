import AppKit
import NotchpadCore
import UserNotifications

/// Sound + notification when a focus session or break ends.
enum FocusAlert {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DebugTools.log("notifications: \(granted)")
        }
    }

    @MainActor
    static func fire(_ kind: FocusKind) {
        NSSound(named: "Glass")?.play()
        let content = UNMutableNotificationContent()
        content.title = kind == .focus ? "Focus done" : "Break over"
        content.body = kind == .focus ? "Time for a 5 minute break." : "Ready for the next session?"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        DebugTools.log("focus finished: \(kind)")
    }
}
