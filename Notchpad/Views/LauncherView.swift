import AppKit
import NotchpadCore
import SwiftUI
import UniformTypeIdentifiers

/// The Shortcuts widget: apps, shortcuts from the Shortcuts app, and folders, one click away.
/// The "Add" tile after the last icon adds one (a native menu: App…, Shortcut ▸, Folder…; SwiftUI's own
/// Menu doesn't open reliably in this panel, which never takes focus). Hovering an icon shows its remove
/// button; files dropped on a folder are copied in.
struct LauncherView: View {
    let inputs: WidgetInputs
    let size: WidgetSize

    private var items: [LauncherItem] { inputs.launcherItems }
    private var compact: Bool { size == .small }
    private var columns: Int { size == .wide ? 9 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 7) {
            Text("SHORTCUTS").font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
            ScrollView(.vertical) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: columns),
                          alignment: .leading, spacing: compact ? 4 : 8) {
                    ForEach(items) { item in
                        LauncherTile(item: item, showTitle: !compact,
                                     copied: inputs.copiedLauncherID == item.id,
                                     onOpen: { inputs.actions.launch(item) },
                                     onRemove: { inputs.actions.removeLauncherItem(item.id) },
                                     onDrop: { inputs.actions.dropOnLauncherFolder(item, $0) },
                                     onReorder: { inputs.actions.moveLauncherItem($0, item.id) })
                    }
                    // Always the last spot: where the next icon will go.
                    LauncherAddTile(showTitle: !compact) { inputs.actions.showLauncherAddMenu() }
                }
            }
            .scrollIndicators(.automatic)
            if items.isEmpty && !compact {
                Text("Add apps, shortcuts or folders").font(.system(size: 11)).foregroundStyle(Color(white: 0.55))
            }
        }
        .onAppear { inputs.actions.refreshShortcutNames() }
    }
}

/// One icon. Folders take dropped files (copied in, a tick shows when done).
struct LauncherTile: View {
    let item: LauncherItem
    let showTitle: Bool
    let copied: Bool
    let onOpen: () -> Void
    let onRemove: () -> Void
    let onDrop: ([URL]) -> Void
    /// Another icon (its id) was dropped on this one: it takes this one's place.
    var onReorder: (UUID) -> Void = { _ in }

    @State private var hovering = false
    @State private var dropTargeted = false

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 3) {
                LauncherIcon(item: item)
                    .frame(width: showTitle ? 34 : 30, height: showTitle ? 34 : 30)
                    .overlay(alignment: .bottomTrailing) {
                        if copied {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                                .foregroundStyle(.white, Color.green)
                        }
                    }
                if showTitle {
                    Text(item.title).font(.system(size: 9, weight: .medium)).lineLimit(1)
                        .truncationMode(.tail).foregroundStyle(Color(white: 0.8))
                }
            }
            .frame(width: 44)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(dropTargeted ? 0.18 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                        .foregroundStyle(.white, Color(white: 0.35))
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: -2)
                .help("Remove")
            }
        }
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: (LauncherTile.dragPrefix + item.id.uuidString) as NSString) }
        .modifier(TileDrop(isFolder: item.kind == .folder, targeted: $dropTargeted, onFiles: onDrop, onReorder: onReorder))
    }

    private var helpText: String {
        switch item.kind {
        case .app: "Open \(item.title)"
        case .shortcut: "Run the shortcut \"\(item.title)\""
        case .folder: "Open \(item.title) in Finder. Drop files here to copy them in."
        }
    }

    /// What a dragged icon carries, so drops can tell an icon from ordinary text.
    static let dragPrefix = "notchpad-launcher:"
}

/// Every icon takes another dragged icon (reorder). Folder icons also take files (copied in);
/// files dropped on other icons fall through to the shelf.
private struct TileDrop: ViewModifier {
    let isFolder: Bool
    @Binding var targeted: Bool
    let onFiles: ([URL]) -> Void
    let onReorder: (UUID) -> Void

    func body(content: Content) -> some View {
        content.onDrop(of: isFolder ? [.fileURL, .plainText] : [.plainText], isTargeted: $targeted) { providers in
            if isFolder, providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
                let group = DispatchGroup()
                let box = URLBox()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url { box.append(url) }
                        group.leave()
                    }
                }
                group.notify(queue: .main) { onFiles(box.urls) }
                return true
            }
            guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                guard let text = value as? String, text.hasPrefix(LauncherTile.dragPrefix),
                      let id = UUID(uuidString: String(text.dropFirst(LauncherTile.dragPrefix.count))) else { return }
                DispatchQueue.main.async { onReorder(id) }
            }
            return true
        }
    }
}

private final class URLBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var urls: [URL] = []
    func append(_ url: URL) { lock.lock(); urls.append(url); lock.unlock() }
}

/// App and folder icons come from Finder (a Google Drive folder shows its own icon);
/// shortcuts use the Shortcuts app's icon. Cached, so drawing never asks Finder again.
struct LauncherIcon: View {
    let item: LauncherItem

    @MainActor private static var cache: [String: NSImage] = [:]

    var body: some View {
        Image(nsImage: Self.icon(for: item)).resizable().interpolation(.high)
    }

    @MainActor static func icon(for item: LauncherItem) -> NSImage {
        let path = item.kind == .shortcut ? "/System/Applications/Shortcuts.app" : item.target
        if let cached = cache[path] { return cached }
        // Some apps are links (Safari on recent macOS): use the real app, so no alias arrow shows.
        let image = NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: path).resolvingSymlinksInPath().path)
        cache[path] = image
        return image
    }
}

/// The "Add" tile: same size as an icon, always right after the last one.
struct LauncherAddTile: View {
    let showTitle: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                AddGridGlyph()
                    .frame(width: showTitle ? 34 : 30, height: showTitle ? 34 : 30)
                if showTitle {
                    Text("Add").font(.system(size: 9, weight: .medium)).foregroundStyle(Color(white: 0.6))
                }
            }
            .frame(width: 44)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add an app, a shortcut or a folder")
    }
}

/// Three outlined squares with a + in the fourth corner, on a dark rounded tile.
struct AddGridGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let cell = side * 0.27, gap = side * 0.09
            let start = (side - 2 * cell - gap) / 2
            let line = Color(white: 0.72)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: side * 0.24).fill(Color(white: 0.16))
                cellBox(cell, line).offset(x: start, y: start)
                cellBox(cell, line).offset(x: start, y: start + cell + gap)
                cellBox(cell, line).offset(x: start + cell + gap, y: start + cell + gap)
                Image(systemName: "plus")
                    .font(.system(size: cell * 0.95, weight: .bold))
                    .foregroundStyle(line)
                    .frame(width: cell, height: cell)
                    .offset(x: start + cell + gap, y: start)
            }
        }
    }

    private func cellBox(_ size: CGFloat, _ color: Color) -> some View {
        RoundedRectangle(cornerRadius: size * 0.28)
            .stroke(color, lineWidth: max(1.2, size * 0.13))
            .frame(width: size, height: size)
    }
}
