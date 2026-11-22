import AppKit
import Combine

/// Everything the panel shows. Readers write into it, views read from it.
@MainActor
final class AppModel: ObservableObject {
    @Published var isOpen = false
    /// Size of the real notch, so the closed shape matches it.
    @Published var notchSize = CGSize(width: 185, height: 32)

    /// Called by the window controller right after the panel opens.
    func panelDidOpen() {}

    /// Called by the window controller right after the panel closes.
    func panelDidClose() {}
}
