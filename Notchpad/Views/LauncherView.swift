import AppKit
import NotchpadCore
import SwiftUI
import UniformTypeIdentifiers

/// The Shortcuts widget: apps, shortcuts from the Shortcuts app, and folders, one click away.
/// "+" adds one; hovering an icon shows its remove button; files dropped on a folder are copied in.
struct LauncherView: View {
    let inputs: WidgetInputs
    let size: WidgetSize

    private var items: [LauncherItem] { inputs.launcherItems }
    private var compact: Bool { size == .small }
    private var columns: Int { size == .wide ? 9 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 7) {
            HStack {
                Text("SHORTCUTS").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    .foregroundStyle(Color(white: 0.55))
                Spacer()
                addMenu
            }
            if items.isEmpty {
                Text("Click + to add apps, shortcuts or folders")
                    .font(.system(size: 11)).foregroundStyle(Color(white: 0.55))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 6), count: columns),
                              alignment: .leading, spacing: compact ? 4 : 8) {
                        ForEach(items) { item in
                            LauncherTile(item: item, showTitle: !compact,
                                         copied: inputs.copiedLauncherID == item.id,
                                         onOpen: { inputs.actions.launch(item) },
                                         onRemove: { inputs.actions.removeLauncherItem(item.id) },
                                         onDrop: { inputs.actions.dropOnLauncherFolder(item, $0) })
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
        .onAppear { inputs.actions.refreshShortcutNames() }
    }

    /// A native menu (App…, Shortcut ▸, Folder…) under the pointer. SwiftUI's own Menu doesn't open
    /// reliably in this panel, which never takes focus.
    private var addMenu: some View {
        AddButton(help: "Add an app, a shortcut or a folder") { inputs.actions.showLauncherAddMenu() }
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
        .modifier(FolderDrop(enabled: item.kind == .folder, targeted: $dropTargeted, onDrop: onDrop))
    }

    private var helpText: String {
        switch item.kind {
        case .app: "Open \(item.title)"
        case .shortcut: "Run the shortcut \"\(item.title)\""
        case .folder: "Open \(item.title) in Finder. Drop files here to copy them in."
        }
    }
}

/// Only folder icons take drops; everything else lets the drop fall through to the shelf.
private struct FolderDrop: ViewModifier {
    let enabled: Bool
    @Binding var targeted: Bool
    let onDrop: ([URL]) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                let group = DispatchGroup()
                let box = URLBox()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url { box.append(url) }
                        group.leave()
                    }
                }
                group.notify(queue: .main) { onDrop(box.urls) }
                return true
            }
        } else {
            content
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
