import NotchpadCore
import SwiftUI

/// The whole panel: a black notch shape that grows into layout A2 when open.
struct NotchRootView: View {
    @ObservedObject var model: AppModel
    @State private var dropTargeted = false

    private var shapeSize: CGSize { model.isOpen ? NotchGeometry.openSize : model.notchSize }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: model.isOpen ? 26 : 8)
                .fill(Color.black)
                .frame(width: shapeSize.width, height: shapeSize.height)
                .shadow(color: .black.opacity(model.isOpen ? 0.45 : 0), radius: 15, y: 8)

            if model.isOpen {
                columns
                    .padding(.top, model.notchSize.height + 4)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                    .frame(width: NotchGeometry.openSize.width, height: NotchGeometry.openSize.height, alignment: .top)
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .frame(width: NotchGeometry.openSize.width, height: NotchGeometry.openSize.height, alignment: .top)
        .foregroundStyle(.white)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { model.shelf.add([url]) }
                }
            }
            return true
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 20) {
            leftColumn.frame(width: 250)
            Rectangle().fill(Color(white: 0.12)).frame(width: 1)
            middleColumn.frame(maxWidth: .infinity, alignment: .leading)
            rightColumn.frame(width: 80, alignment: .trailing)
        }
    }

    // Replaced by the feature views in later tasks.
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicView(state: model.music, artwork: model.artwork, now: model.clock,
                      onCommand: { model.sendMusic($0) }, onOpenMusic: { model.openMusic() })
            ShelfView(store: model.shelf, isDropTargeted: dropTargeted,
                      onDragActive: { model.onShelfDragActive?($0) })
        }
    }
    private var middleColumn: some View {
        EventsView(events: model.events, access: model.calendarAccess)
    }
    private var rightColumn: some View {
        StatsView(battery: model.battery, temperature: model.temperature)
    }
}
