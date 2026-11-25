import NotchpadCore
import SwiftUI

/// What edit mode can do to the widgets of the tab on screen.
@MainActor
struct GridEditor {
    let remove: (UUID) -> Void
    let canResize: (UUID, WidgetSize) -> Bool
    let resize: (UUID, WidgetSize) -> Void
    let move: (UUID, Int, SlotHalf) -> Bool
    /// A point in the grid's coordinates: true when it's over another tab and the drop was handled there.
    var dropOnTab: (UUID, CGPoint) -> Bool = { _, _ in false }
    /// While dragging: light up the tab under the pointer (nil = none).
    var hoverTab: (CGPoint?) -> Void = { _ in }
}

/// One tab's widgets on the 3-column grid. With an editor: ⊖, size menu, drag to move.
struct WidgetGridView: View {
    static let gap: CGFloat = 10
    let page: TabPage
    let inputs: WidgetInputs
    var editor: GridEditor?

    @State private var draggingID: UUID?
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if editor != nil {
                    freeCells(in: geo.size)
                } else if page.widgets.isEmpty {
                    Text("Right-click → Edit widgets to add some")
                        .font(.system(size: 12)).foregroundStyle(Color(white: 0.45))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                ForEach(page.widgets) { w in
                    let frame = WidgetGrid.frame(size: w.size, column: w.column, half: w.half, in: geo.size, gap: Self.gap)
                    widget(w, area: geo.size)
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX + (draggingID == w.id ? dragOffset.width : 0),
                                y: frame.minY + (draggingID == w.id ? dragOffset.height : 0))
                        .zIndex(draggingID == w.id ? 1 : 0)
                }
            }
            .coordinateSpace(name: "grid")
        }
    }

    @ViewBuilder private func widget(_ w: WidgetPlacement, area: CGSize) -> some View {
        let view = WidgetView(kind: w.kind, size: w.size, inputs: inputs)
        if let editor {
            view
                .allowsHitTesting(false)
                .opacity(draggingID == w.id ? 0.7 : 0.85)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(white: 0.3), lineWidth: 1))
                .contentShape(Rectangle())
                .gesture(moveGesture(w, area: area, editor: editor))
                .overlay(alignment: .topLeading) {
                    Button { editor.remove(w.id) } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 15))
                            .foregroundStyle(.white, Color(white: 0.4))
                    }
                    .buttonStyle(.plain)
                    .offset(x: -6, y: -6)
                    .help("Remove")
                }
                .overlay(alignment: .topTrailing) {
                    if w.kind.sizes.count > 1 {
                        Menu {
                            ForEach(w.kind.sizes, id: \.self) { size in
                                Button {
                                    editor.resize(w.id, size)
                                } label: {
                                    if size == w.size { Label(size.title, systemImage: "checkmark") } else { Text(size.title) }
                                }
                                .disabled(size != w.size && !editor.canResize(w.id, size))
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color(white: 0.3)))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .offset(x: 4, y: -4)
                        .help("Size")
                    }
                }
        } else {
            view
        }
    }

    /// Faint dashed outlines where a widget could go.
    private func freeCells(in area: CGSize) -> some View {
        let taken = page.widgets.compactMap(WidgetGrid.cells(of:)).reduce(into: Set<GridCell>()) { $0.formUnion($1) }
        let free = (0..<WidgetGrid.columns).flatMap { c in [0, 1].map { GridCell(column: c, row: $0) } }
            .filter { !taken.contains($0) }
        return ForEach(free, id: \.self) { cell in
            let frame = WidgetGrid.frame(size: .small, column: cell.column, half: cell.row == 0 ? .top : .bottom,
                                         in: area, gap: Self.gap)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(white: 0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
        }
    }

    /// Drag a widget; on release it moves to the spot under the pointer (or swaps), else snaps back.
    private func moveGesture(_ w: WidgetPlacement, area: CGSize, editor: GridEditor) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("grid"))
            .onChanged { value in
                draggingID = w.id
                dragOffset = value.translation
                editor.hoverTab(value.location)
            }
            .onEnded { value in
                editor.hoverTab(nil)
                // Dropped on another tab's name: it moves to that tab (or the tab flashes red).
                if editor.dropOnTab(w.id, value.location) {
                    draggingID = nil
                    dragOffset = .zero
                    return
                }
                defer {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        draggingID = nil
                        dragOffset = .zero
                    }
                }
                guard let start = WidgetGrid.cell(at: value.startLocation, in: area),
                      let end = WidgetGrid.cell(at: value.location, in: area) else { return }
                // Keep the grab point under the pointer for widgets wider than one column.
                let grabOffset = start.column - w.column
                let column = min(max(end.column - grabOffset, 0), WidgetGrid.columns - w.size.columns)
                let half: SlotHalf = w.size == .small ? (end.row == 0 ? .top : .bottom) : .full
                let moved = editor.move(w.id, column, half)
                DebugTools.log(moved ? "moved: \(w.kind.rawValue) c\(column) \(half.rawValue)" : "move refused")
            }
    }
}
