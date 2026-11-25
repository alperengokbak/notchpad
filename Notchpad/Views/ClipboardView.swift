import AppKit
import NotchpadCore
import SwiftUI

/// Clipboard widget: the last 30 copies. Click one to copy it again; hover for ×; "Clear" empties it.
struct ClipboardView: View {
    @ObservedObject var monitor: ClipboardMonitor
    let now: Date
    /// Turned off from the right-click menu: new copies aren't saved.
    var paused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CLIPBOARD").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    .foregroundStyle(Color(white: 0.55))
                if paused {
                    Text("PAUSED").font(.system(size: 9, weight: .semibold)).tracking(0.5)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.orange.opacity(0.25)))
                        .foregroundStyle(Color.orange)
                        .help("New copies aren't saved. Right-click to resume.")
                }
                Spacer()
                if !monitor.history.entries.isEmpty {
                    Button("Clear") { monitor.clear() }.buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.6))
                        .help("Forget everything in the clipboard history")
                }
            }
            if monitor.history.entries.isEmpty {
                Text("Copy something and it shows up here").font(.system(size: 11)).foregroundStyle(Color(white: 0.55))
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(monitor.history.entries) { entry in
                            ClipRow(entry: entry, copied: monitor.copiedID == entry.id, now: now,
                                    onCopy: { monitor.copyAgain(entry) }, onRemove: { monitor.remove(entry.id) })
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
    }
}

private struct ClipRow: View {
    let entry: ClipEntry
    let copied: Bool
    let now: Date
    let onCopy: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onCopy) {
                HStack(spacing: 6) {
                    if let data = entry.imageData, let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 28, height: 20).clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("Picture").font(.system(size: 12)).foregroundStyle(Color(white: 0.8))
                    } else {
                        Text(oneLine(entry.text ?? "")).font(.system(size: 12)).lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 4)
                    Text(copied ? "Copied" : RecentFiles.ago(entry.date, now: now))
                        .font(.system(size: 10, weight: copied ? .semibold : .regular))
                        .foregroundStyle(copied ? Color.green : Color(white: 0.5))
                        .fixedSize()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Click to copy again")
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(Color(white: 0.5))
                }
                .buttonStyle(.plain).help("Remove from history")
            }
        }
        .padding(.vertical, 2)
        .onHover { hovering = $0 }
    }

    private func oneLine(_ s: String) -> String {
        s.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? s
    }
}
