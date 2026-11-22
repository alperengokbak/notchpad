import AppKit
import NotchpadCore
import SwiftUI

/// Left column, under the player: files waiting to be dragged out.
struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    let isDropTargeted: Bool
    let onDragActive: (Bool) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDropTargeted ? Color.white : Color(white: 0.27),
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            if store.items.isEmpty {
                Text("Drop files here").font(.system(size: 11)).foregroundStyle(Color(white: 0.47))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.items) { item in ShelfItemView(item: item, store: store, onDragActive: onDragActive) }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        .frame(height: 62)
    }
}

private struct ShelfItemView: View {
    let item: ShelfItem
    @ObservedObject var store: ShelfStore
    let onDragActive: (Bool) -> Void
    @State private var hovering = false

    var body: some View {
        let url = store.url(for: item.id)
        VStack(spacing: 3) {
            Group {
                if let url {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                } else {
                    // The file's disk is disconnected: show it dimmed until it's back.
                    Image(systemName: "externaldrive.badge.xmark").resizable().aspectRatio(contentMode: .fit)
                        .foregroundStyle(Color(white: 0.5))
                }
            }
            .frame(width: 30, height: 36)
            Text(item.name).font(.system(size: 9)).foregroundStyle(Color(white: 0.8))
                .lineLimit(1).truncationMode(.middle).frame(width: 44)
        }
        .opacity(url == nil ? 0.45 : 1)
        .overlay {
            if let url {
                ShelfItemDragView(url: url,
                                  onDragStarted: { onDragActive(true) },
                                  onDragEnded: { accepted in
                                      store.dragEnded(item.id, accepted: accepted)
                                      onDragActive(false)
                                  })
            }
        }
        .overlay(alignment: .topTrailing) {
            if hovering {
                HStack(spacing: 2) {
                    if let url {
                        Button { AirDrop.send([url]) } label: {
                            Image(systemName: "dot.radiowaves.up.forward").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 15, height: 15)
                                .background(Circle().fill(Color.blue))
                        }
                        .buttonStyle(.plain)
                        .help("AirDrop")
                    }
                    Button { store.remove(item.id) } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                            .foregroundStyle(.white, Color(white: 0.35))
                    }
                    .buttonStyle(.plain)
                }
                .offset(x: 6, y: -4)
            }
        }
        .onHover { hovering = $0 }
    }
}
