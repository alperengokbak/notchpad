import NotchpadCore
import SwiftUI

/// The whole panel: a black notch shape that grows into the selected tab's widgets when open.
struct NotchRootView: View {
    @ObservedObject var model: AppModel
    @State private var dropTargeted = false

    private var shapeSize: CGSize { model.isOpen ? NotchGeometry.openSize : model.notchSize }
    /// The extensions beside the closed notch (none while open).
    private var wings: WingWidths { model.isOpen ? WingWidths(left: 0, right: 0) : model.closedWings }
    private var musicWings: Bool { !model.isOpen && model.showClosedMusic && model.music.isPlaying }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: model.isOpen ? 26 : 8)
                .fill(Color.black)
                .frame(width: shapeSize.width + wings.left + wings.right, height: shapeSize.height)
                .overlay(alignment: .topLeading) {
                    if wings.left > 0 {
                        HStack(spacing: 0) {
                            if model.focus.isActive {
                                FocusWing(timer: model.focus, now: model.clock).frame(width: 70)
                            }
                            if let elapsed = model.mic.elapsed(now: model.clock) {
                                MicWing(elapsed: elapsed).frame(width: 70)
                            }
                            if musicWings {
                                MusicCoverWing(artwork: model.artwork).frame(width: 36)
                            }
                        }
                        .frame(width: wings.left, height: model.notchSize.height, alignment: .leading)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if musicWings {
                        MusicBarsWing().frame(width: wings.right, height: model.notchSize.height)
                    }
                }
                .offset(x: (wings.right - wings.left) / 2)
                .animation(.easeOut(duration: 0.25), value: wings)
                .shadow(color: .black.opacity(model.isOpen ? 0.45 : 0), radius: 15, y: 8)

            if model.isOpen {
                TabStrip(model: model, panelWidth: NotchGeometry.openSize.width, notchSize: model.notchSize)
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

    @ViewBuilder private var content: some View {
        if let item = model.editor {
            ItemEditor(item: item, lists: item.isReminder ? model.reminderLists : model.eventCalendars,
                       error: model.editorError,
                       onSave: { model.saveEditor($0) }, onDelete: { model.deleteEditorItem($0) },
                       onCancel: { model.cancelEditor() })
                .id(model.editorToken)
        } else {
            WidgetGridView(page: model.layout.selectedTab, inputs: model.widgetInputs(dropTargeted: dropTargeted),
                           editor: model.isEditing ? editor : nil)
        }
    }

    private var editor: GridEditor {
        let tab = model.selectedTabID
        return GridEditor(
            remove: { model.layout.removeWidget($0, fromTab: tab) },
            canResize: { model.layout.canResize($0, to: $1, inTab: tab) },
            resize: { _ = model.layout.resizeWidget($0, to: $1, inTab: tab) },
            move: { model.layout.moveWidget($0, toColumn: $1, half: $2, inTab: tab) })
    }
}
