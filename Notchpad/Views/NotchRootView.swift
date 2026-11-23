import NotchpadCore
import SwiftUI

/// The whole panel: a black notch shape that grows into the selected tab's widgets when open.
struct NotchRootView: View {
    @ObservedObject var model: AppModel
    @State private var dropTargeted = false

    private var shapeSize: CGSize { model.isOpen ? NotchGeometry.openSize : model.notchSize }
    /// Width of the countdown extension: only while closed with a timer running or paused.
    private var wingWidth: CGFloat { model.isOpen ? 0 : model.stripWidth }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: model.isOpen ? 26 : 8)
                .fill(Color.black)
                .frame(width: shapeSize.width + wingWidth, height: shapeSize.height)
                .overlay(alignment: .topLeading) {
                    if wingWidth > 0 {
                        HStack(spacing: 0) {
                            if model.focus.isActive {
                                FocusWing(timer: model.focus, now: model.clock).frame(width: 70)
                            }
                            if let elapsed = model.mic.elapsed(now: model.clock) {
                                MicWing(elapsed: elapsed).frame(width: 70)
                            }
                        }
                        .frame(width: wingWidth, height: model.notchSize.height, alignment: .leading)
                    }
                }
                .offset(x: -wingWidth / 2)
                .shadow(color: .black.opacity(model.isOpen ? 0.45 : 0), radius: 15, y: 8)

            if model.isOpen {
                TabBar(tabs: model.layout.tabs, selectedID: model.selectedTabID, onSelect: { model.selectTab($0) })
                    .frame(width: NotchGeometry.openSize.width, height: model.notchSize.height, alignment: .leading)
                    .padding(.leading, 44)
                    .frame(width: NotchGeometry.openSize.width, alignment: .leading)
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
                content
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
                    DispatchQueue.main.async { model.dropFiles([url]) }
                }
            }
            return true
        }
    }

    private var content: some View {
        WidgetGridView(page: model.layout.selectedTab, inputs: model.widgetInputs(dropTargeted: dropTargeted))
    }
}
