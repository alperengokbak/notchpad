import AppKit

/// Opens Apple's AirDrop window with the given files; he picks the device there.
enum AirDrop {
    @MainActor
    static func send(_ urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls) else { return }
        // The AirDrop window belongs to Notchpad, so bring Notchpad forward for it (he asked for this).
        NSApp.activate()
        service.perform(withItems: urls)
        DebugTools.log("airdrop: \(urls.count) file(s)")
    }
}
