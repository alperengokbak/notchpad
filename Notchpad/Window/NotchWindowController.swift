import AppKit
import Combine
import NotchpadCore
import SwiftUI

/// Places the panel over the notch of the built-in screen and opens/closes it.
@MainActor
final class NotchWindowController {
    private let model: AppModel
    private var machine = PanelStateMachine()
    private let monitors = MouseMonitors()
    private var panel: NotchPanel?
    private var tickTimer: Timer?
    private var notch: CGRect = .zero
    private var openRect: CGRect = .zero
    /// The app that was in front before edit mode took focus; it gets focus back on Done.
    private var frontAppBeforeEdit: NSRunningApplication?
    private lazy var gallery = GalleryWindowController(model: model)
    private var galleryWatch: AnyCancellable?
    private var displayWatch: AnyCancellable?

    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    init(model: AppModel, forceOpen: Bool) {
        self.model = model
        machine.forceOpen = forceOpen
    }

    func start() {
        model.onShelfDragActive = { [weak self] active in
            guard let self else { return }
            self.machine.setShelfDragActive(active, now: ProcessInfo.processInfo.systemUptime)
            self.sync()
        }
        model.onEditingChanged = { [weak self] on in self?.setEditing(on) }
        model.onTypingChanged = { [weak self] on in self?.setTyping(on) }
        galleryWatch = model.$showGallery.removeDuplicates().sink { [weak self] show in
            DispatchQueue.main.async { self?.setGalleryVisible(show) }
        }
        displayWatch = model.$preferMainDisplay.removeDuplicates().dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.layout() }
        }
        monitors.onMouseMoved = { [weak self] point in self?.mouseMoved(to: point) }
        monitors.onFileDragMoved = { [weak self] point in self?.fileDragMoved(to: point) }
        monitors.onScroll = { [weak self] event in self?.scrolled(event) }
        monitors.start()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }
        layout()
        sync()
    }

    /// The built-in display, if it's connected and awake.
    private static func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
    }

    /// Every screen as the core sees it. The first screen in the list is the one with the menu bar.
    private static func screenInfos() -> [ScreenInfo] {
        NSScreen.screens.enumerated().map { i, screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            return ScreenInfo(frame: screen.frame, isBuiltIn: id.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
                              isMain: i == 0,
                              metrics: ScreenMetrics(frame: screen.frame,
                                                     leftAuxWidth: screen.auxiliaryTopLeftArea?.width,
                                                     rightAuxWidth: screen.auxiliaryTopRightArea?.width,
                                                     safeTop: screen.safeAreaInsets.top),
                              menuBarHeight: menuBar > 0 ? menuBar : 24)
        }
    }

    /// The real notch on a notched MacBook; otherwise (or with "Show on the main display") a drawn notch
    /// at the top centre of the main screen.
    func layout() {
        guard let pick = NotchGeometry.pickScreen(Self.screenInfos(), preferMain: model.preferMainDisplay),
              NSScreen.screens.indices.contains(pick.index) else {
            panel?.orderOut(nil)
            return
        }
        let screen = NSScreen.screens[pick.index]
        let notchRect = pick.notch
        DebugTools.log("screen: \(pick.isVirtual ? "virtual" : "real") notch \(Int(notchRect.width))x\(Int(notchRect.height))")
        notch = notchRect
        openRect = NotchGeometry.openRect(notch: notchRect, screen: screen.frame)
        model.notchSize = notchRect.size

        if panel == nil {
            let p = NotchPanel(frame: openRect)
            let host = PanelHostingView(rootView: NotchRootView(model: model))
            host.shelf = model.shelf
            host.isEditing = { [weak model] in model?.isEditing ?? false }
            host.micShown = { [weak model] in model?.showMicIndicator ?? true }
            host.onToggleMic = { [weak model] in model?.showMicIndicator.toggle() }
            host.closedMusicShown = { [weak model] in model?.showClosedMusic ?? true }
            host.onToggleClosedMusic = { [weak model] in model?.showClosedMusic.toggle() }
            host.hasBackground = { [weak model] in model?.backgroundImage != nil }
            host.onChooseBackground = { [weak model] in model?.chooseBackground() }
            host.onRemoveBackground = { [weak model] in model?.removeBackground() }
            host.toggles = { [weak model] in
                guard let model else { return [] }
                return [
                    MenuToggle(title: "Swipe on the notch to change songs", isOn: model.swipeToChangeSongs) { model.swipeToChangeSongs.toggle() },
                    MenuToggle(title: "Show charging on closed notch", isOn: model.showChargingAnimation) { model.showChargingAnimation.toggle() },
                    MenuToggle(title: "Shelf: newest files first", isOn: model.shelfNewestFirst) { model.shelfNewestFirst.toggle() },
                    MenuToggle(title: "Open when dragging files to the notch", isOn: model.openOnFileDrag) { model.openOnFileDrag.toggle() },
                    MenuToggle(title: "Add new screenshots to the shelf", isOn: model.screenshotsToShelf) { model.screenshotsToShelf.toggle() },
                    MenuToggle(title: "Show on the main display", isOn: model.preferMainDisplay) { model.preferMainDisplay.toggle() },
                    model.updateAvailable.map { u in MenuToggle(title: "Update available: Notchpad \(u.version)…", isOn: nil) { model.openUpdatePage() } }
                        ?? MenuToggle(title: "Check for updates…", isOn: nil) { model.runUpdateCheck(manual: true) },
                    MenuToggle(title: "Check for updates automatically", isOn: model.checkForUpdates) { model.checkForUpdates.toggle() },
                ]
            }
            host.onEditWidgets = { [weak model] in
                guard let model else { return }
                if model.isEditing { model.endEditing() } else { model.beginEditing() }
            }
            host.frame = NSRect(origin: .zero, size: openRect.size)
            model.onShowMenu = { [weak host, weak model] in
                guard let host, let model else { return }
                DebugTools.log("menu: settings button")
                host.showMenu(belowRightEdge: host.bounds.width - 22, top: model.notchSize.height + 2)
            }
            p.contentView = host
            panel = p
            // A click anywhere in the panel except the focus length box ends typing there and keeps
            // what was typed (like Return), the way text boxes work everywhere else on the Mac.
            // Done on mouse up, so a button clicked meanwhile (−, +, Start) still gets its whole click.
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self, let panel = self.panel, event.window === panel,
                          self.model.editingFocusMinutes || self.model.editingNote,
                          !Self.isTextInput(at: event, in: panel) else { return }
                    DebugTools.log("typing: clicked elsewhere")
                    if self.model.editingNote { self.model.endNoteEditing(); return }
                    // After the click has been handled, so a button's action runs first.
                    DispatchQueue.main.async { panel.makeFirstResponder(nil) }
                }
                return event
            }
            // He clicked another app while the editor was open: drop the editor so the panel can close.
            NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: p,
                                                   queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    // Checked a moment later: a menu or picker opening inside the panel gives focus straight back.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        guard let self, self.model.wantsTyping, !self.model.isEditing,
                              self.panel?.isKeyWindow != true else { return }
                        DebugTools.log("editor: lost focus")
                        self.model.cancelEditor()
                        self.model.endFocusMinutesTyping(nil)
                        self.model.endNoteEditing()
                    }
                }
            }
        }
        panel?.setFrame(openRect, display: true)
        panel?.orderFrontRegardless()
    }

    /// Edit mode holds the panel open and lets it take typing; Done hands focus back.
    private func setEditing(_ on: Bool) {
        machine.setEditing(on, now: ProcessInfo.processInfo.systemUptime)
        updateKeyFocus()
        sync()
    }

    /// The reminder/event editor: same as edit mode, the panel stays open and takes typing until it closes.
    private func setTyping(_ on: Bool) {
        machine.setTyping(on, now: ProcessInfo.processInfo.systemUptime)
        updateKeyFocus()
        sync()
    }

    /// Whether the panel currently holds keyboard focus (edit mode or the editor).
    private var hasKeyFocus = false
    private var clickMonitor: Any?

    /// True when the click lands on the text box being typed in. The box is found through the window's
    /// field editor (the text view macOS puts inside a box while you type), not by hit-testing,
    /// because SwiftUI hosts its text fields in views that hit-testing doesn't report.
    private static func isTextInput(at event: NSEvent, in panel: NSPanel) -> Bool {
        guard let editor = panel.firstResponder as? NSTextView else { return false }
        // A one-line box uses the shared field editor; the note is a real text view in a scroll view.
        let box: NSView = editor.isFieldEditor ? ((editor.delegate as? NSView) ?? editor) : (editor.enclosingScrollView ?? editor)
        let frame = box.convert(box.bounds, to: nil).insetBy(dx: -4, dy: -4)
        return frame.contains(event.locationInWindow)
    }

    /// Takes keyboard focus while edit mode or the editor needs it; hands it back to his app after.
    private func updateKeyFocus() {
        let want = model.isEditing || model.wantsTyping
        guard want != hasKeyFocus else {
            if want { panel?.makeKey() }
            return
        }
        hasKeyFocus = want
        if want {
            let front = NSWorkspace.shared.frontmostApplication
            if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { frontAppBeforeEdit = front }
            panel?.allowsKey = true
            NSApp.activate(ignoringOtherApps: true)
            panel?.makeKey()
        } else {
            panel?.allowsKey = false
            panel?.resignKey()
            // Only if Notchpad still has focus: if he switched to another app meanwhile, leave it there.
            if NSApp.isActive { frontAppBeforeEdit?.activate() }
            frontAppBeforeEdit = nil
        }
    }

    private func setGalleryVisible(_ show: Bool) {
        if show, model.isEditing {
            let level = NSWindow.Level(rawValue: (panel?.level.rawValue ?? NSWindow.Level.floating.rawValue) - 1)
            gallery.show(below: openRect, level: level)
        } else {
            gallery.close()
            if model.isEditing { panel?.makeKey() }
        }
    }

    /// For `--snapshot-gallery`: the gallery's content view.
    var galleryContentView: NSView? { gallery.contentView }

    /// For `--snapshot`: the panel's content view.
    var contentView: NSView? { panel?.contentView }

    private func mouseMoved(to point: CGPoint) {
        let zone = machine.isOpen ? openRect
            : NotchGeometry.hotZone(notch: notch, wings: model.closedWings)
        machine.pointer(inside: zone.contains(point), now: ProcessInfo.processInfo.systemUptime)
        sync()
    }

    private var swipe = SwipeDetector()

    /// Two-finger swipe over the notch (open or closed): left = next song, right = previous.
    private func scrolled(_ event: NSEvent) {
        guard model.swipeToChangeSongs else { return }
        let zone = NotchGeometry.hotZone(notch: notch, wings: machine.isOpen ? WingWidths(left: 0, right: 0) : model.closedWings)
        let phase: SwipeDetector.Phase
        switch event.phase {
        case .began: phase = .began
        case .changed: phase = .changed
        case .ended, .cancelled: phase = .ended
        default: phase = .other
        }
        // Only gestures that start over the notch count; the rest of the screen scrolls as usual.
        if phase == .began, !zone.contains(NSEvent.mouseLocation) { swipe = SwipeDetector(); swipeActive = false; return }
        if phase == .began { swipeActive = true }
        guard swipeActive else { return }
        if let action = swipe.feed(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY, phase: phase,
                                   momentum: !event.momentumPhase.isEmpty, inverted: event.isDirectionInvertedFromDevice) {
            model.swipeMusic(action)
        }
        if phase == .ended { swipeActive = false }
    }
    private var swipeActive = false

    /// A file drag coming within 40 pt below the hot zone opens the panel straight away.
    private func fileDragMoved(to point: CGPoint) {
        guard !machine.isOpen, model.openOnFileDrag else { return }
        var zone = NotchGeometry.hotZone(notch: notch)
        zone.origin.y -= 40
        zone.size.height += 40
        if zone.contains(point) {
            machine.fileDragNearNotch(now: ProcessInfo.processInfo.systemUptime)
            sync()
        }
    }

    /// Applies the state machine's decision to the window and model, and runs the
    /// 50 ms tick only while a delayed open or close is waiting.
    private func sync() {
        if machine.isOpen != model.isOpen {
            let open = machine.isOpen
            panel?.ignoresMouseEvents = !open
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { model.isOpen = open }
            DebugTools.log(open ? "open" : "closed")
            if open { model.panelDidOpen(); onOpen?() } else { model.panelDidClose(); onClose?() }
        }
        if machine.hasPendingDeadline {
            guard tickTimer == nil else { return }
            tickTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.machine.tick(now: ProcessInfo.processInfo.systemUptime)
                    self.sync()
                }
            }
        } else {
            tickTimer?.invalidate()
            tickTimer = nil
        }
    }
}

/// Hosting view that shows the panel menu on right-click.
final class PanelHostingView<Content: View>: NSHostingView<Content> {
    weak var shelf: ShelfStore?
    var isEditing: () -> Bool = { false }
    var onEditWidgets: () -> Void = {}
    var micShown: () -> Bool = { true }
    var onToggleMic: () -> Void = {}
    var closedMusicShown: () -> Bool = { true }
    var onToggleClosedMusic: () -> Void = {}
    var hasBackground: () -> Bool = { false }
    var onChooseBackground: () -> Void = {}
    var onRemoveBackground: () -> Void = {}
    var toggles: () -> [MenuToggle] = { [] }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(makeMenu(), with: event, for: self)
    }

    /// The same menu, opened by the settings button: its top-right corner under the button.
    func showMenu(belowRightEdge x: CGFloat, top: CGFloat) {
        let menu = makeMenu()
        let width = menu.size.width
        let y = isFlipped ? top : bounds.height - top
        menu.popUp(positioning: nil, at: NSPoint(x: x - width, y: y), in: self)
    }

    private func makeMenu() -> NSMenu {
        PanelMenu.make(shelf: shelf, editing: isEditing(), onEditWidgets: onEditWidgets,
                       micShown: micShown(), onToggleMic: onToggleMic,
                       closedMusicShown: closedMusicShown(), onToggleClosedMusic: onToggleClosedMusic,
                       hasBackground: hasBackground(), onChooseBackground: onChooseBackground,
                       onRemoveBackground: onRemoveBackground, toggles: toggles())
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
