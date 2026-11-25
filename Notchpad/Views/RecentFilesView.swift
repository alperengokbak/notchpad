import AppKit
import NotchpadCore
import SwiftUI

/// Recent files widget: files opened in the last week. Click to open, drag one out, or hover for "Show in Finder".
struct RecentFilesView: View {
    let files: [RecentFile]
    let now: Date
    let onOpen: (RecentFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT FILES").font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
            if files.isEmpty {
                Text("Files you open show up here").font(.system(size: 11)).foregroundStyle(Color(white: 0.55))
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(files) { file in RecentFileRow(file: file, now: now, onOpen: { onOpen(file) }) }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
    }
}

private struct RecentFileRow: View {
    let file: RecentFile
    let now: Date
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onOpen) {
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path)).resizable().frame(width: 18, height: 18)
                    Text(file.url.lastPathComponent).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    if !hovering {
                        Text(RecentFiles.ago(file.date, now: now)).font(.system(size: 10)).foregroundStyle(Color(white: 0.5)).fixedSize()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(file.url.path)
            .onDrag { NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }
            if hovering {
                Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(Color(white: 0.7))
                }
                .buttonStyle(.plain).help("Show in Finder")
            }
        }
        .padding(.vertical, 1)
        .onHover { hovering = $0 }
    }
}
