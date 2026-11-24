import AppKit
import NotchpadCore
import SwiftUI

/// The tab pills in the strip beside the notch. Tabs stay together left of the notch (they give up
/// padding, then shrink) and only continue right of it when even that doesn't fit. In edit mode: rename, delete, reorder, add,
/// plus "Add widget" and "Done" on the far right.
struct TabStrip: View {
    @ObservedObject var model: AppModel
    let panelWidth: CGFloat
    let notchSize: CGSize

    private static let font = NSFont.systemFont(ofSize: 11, weight: .medium)
    private static let edge: CGFloat = 22
    private static let spacing: CGFloat = 6
    private static let notchGap: CGFloat = 10
    private static let gearSize: CGFloat = 22

    @State private var renamingID: UUID?
    @State private var draft = ""
    @State private var rejectedID: UUID?
    @State private var confirmDeleteID: UUID?
    @State private var draggingID: UUID?
    @State private var dragDX: CGFloat = 0
    @FocusState private var nameFocused: Bool

    private var tabs: [TabPage] { model.layout.tabs }
    private var editing: Bool { model.isEditing }

    var body: some View {
        let slots = layoutSlots()
        ZStack(alignment: .topLeading) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                let slot = slots.tabs[index]
                pill(tab, width: slot.width)
                    .position(x: slot.midX + (draggingID == tab.id ? dragDX : 0), y: notchSize.height / 2)
                    .zIndex(draggingID == tab.id ? 1 : 0)
                    .gesture(editing && renamingID == nil ? reorderGesture(tab, slots: slots) : nil)
            }
            if editing {
                if let plus = slots.plus {
                    let full = tabs.count >= PanelLayout.maxTabs
                    circleButton("plus") { addTab() }
                        .disabled(full)
                        .opacity(full ? 0.35 : 1)
                        .position(x: plus, y: notchSize.height / 2)
                        .help(full ? "Up to \(PanelLayout.maxTabs) tabs" : "Add a tab")
                }
                HStack(spacing: Self.spacing) {
                    textButton("Add widget", filled: false) { model.showGallery = true }
                    textButton("Done", filled: true) { finishRename(); model.endEditing() }
                }
                .frame(height: notchSize.height)
                .frame(width: panelWidth - Self.edge, alignment: .trailing)
            } else {
                // Settings: the same menu as a right-click, for people who don't think of right-clicking.
                circleButton("gearshape.fill") { model.onShowMenu?() }
                    .position(x: panelWidth - Self.edge - Self.gearSize / 2, y: notchSize.height / 2)
                    .help("Settings")
            }
        }
        .frame(width: panelWidth, height: notchSize.height, alignment: .topLeading)
        .onChange(of: editing) { _, on in if !on { renamingID = nil; confirmDeleteID = nil } }
    }

    // MARK: Layout

    private struct Slots {
        var tabs: [(midX: CGFloat, width: CGFloat)]
        var plus: CGFloat?
    }

    private static func textWidth(_ s: String) -> CGFloat {
        ceil((s as NSString).size(withAttributes: [.font: font]).width)
    }

    private var controlsWidth: CGFloat {
        Self.textWidth("Add widget") + 24 + Self.spacing + Self.textWidth("Done") + 24
    }

    /// Where each pill goes: left of the notch while it fits, then right of it.
    private func layoutSlots() -> Slots {
        let leftStart = Self.edge
        let leftEnd = panelWidth / 2 - notchSize.width / 2 - Self.notchGap
        let rightStart = panelWidth / 2 + notchSize.width / 2 + Self.notchGap
        let rightEnd = panelWidth - Self.edge - (editing ? controlsWidth : Self.gearSize) - Self.spacing
        let plusWidth: CGFloat = editing ? 22 : 0
        let widths = tabs.map { tab -> CGFloat in
            // While renaming, just enough room for the name being typed (it grows as he types).
            let text = tab.id == renamingID ? max(Self.textWidth(draft) + 4, 34) : Self.textWidth(tab.name)
            return text + 20
        }
        let placed = TabStripLayout.place(widths: widths, leftStart: leftStart, leftEnd: leftEnd,
                                          rightStart: rightStart, rightEnd: rightEnd, plusWidth: plusWidth,
                                          plusIsOptional: tabs.count >= PanelLayout.maxTabs,
                                          spacing: Self.spacing)
        return Slots(tabs: zip(placed.mids, placed.widths).map { (midX: $0, width: $1) }, plus: placed.plusMid)
    }

    // MARK: Pills

    @ViewBuilder private func pill(_ tab: TabPage, width: CGFloat) -> some View {
        let selected = model.selectedTabID == tab.id
        let deleting = confirmDeleteID == tab.id
        // Side padding shrinks before the name gets cut, when the pills had to get narrower.
        let shown = renamingID == tab.id ? draft : (deleting ? "Delete?" : tab.name)
        let pad = max(3, min(10, (width - Self.textWidth(shown)) / 2))
        Group {
            if renamingID == tab.id {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .focused($nameFocused)
                    .onSubmit { finishRename() }
                    .onChange(of: nameFocused) { _, focused in if !focused { finishRename() } }
                    .padding(.horizontal, pad).padding(.vertical, 4)
                    .frame(width: width)
                    .background(Capsule().fill(Color.white))
            } else {
                Button { tapped(tab) } label: {
                    Text(deleting ? "Delete?" : tab.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(deleting ? Color.white : (selected ? Color.black : Color(white: 0.67)))
                        .padding(.horizontal, pad).padding(.vertical, 4)
                        .frame(width: width)
                        .background(Capsule().fill(deleting ? Color.red : (selected ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.13))))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Capsule().strokeBorder(Color.red, lineWidth: rejectedID == tab.id ? 2 : 0))
        .overlay(alignment: .topLeading) {
            // Also on the tab being renamed, so a tab just added with + can be deleted straight away.
            if editing, tabs.count > 1, !deleting {
                Button { deleteTapped(tab) } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 11))
                        .foregroundStyle(.white, Color(white: 0.4))
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
                .help("Delete tab")
            }
        }
    }

    private func tapped(_ tab: TabPage) {
        if confirmDeleteID == tab.id {
            confirmDeleteID = nil
            _ = model.layout.deleteTab(tab.id)
            return
        }
        confirmDeleteID = nil
        if editing, model.selectedTabID == tab.id {
            startRename(tab)
        } else {
            finishRename()
            model.selectTab(tab.id)
        }
    }

    private func deleteTapped(_ tab: TabPage) {
        finishRename()
        if tab.widgets.isEmpty {
            _ = model.layout.deleteTab(tab.id)
        } else {
            confirmDeleteID = tab.id
        }
    }

    private func addTab() {
        finishRename()
        confirmDeleteID = nil
        if let id = model.layout.addTab(), let tab = model.layout.tab(id) { startRename(tab) }
    }

    private func startRename(_ tab: TabPage) {
        draft = tab.name
        renamingID = tab.id
        DispatchQueue.main.async { nameFocused = true }
    }

    private func finishRename() {
        guard let id = renamingID else { return }
        renamingID = nil
        let unchanged = model.layout.tab(id)?.name == draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !unchanged, !model.layout.renameTab(id, to: draft) {
            rejectedID = id
            DebugTools.log("rename refused: \(draft)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if rejectedID == id { rejectedID = nil } }
        }
    }

    private func reorderGesture(_ tab: TabPage, slots: Slots) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                confirmDeleteID = nil
                draggingID = tab.id
                dragDX = value.translation.width
            }
            .onEnded { value in
                draggingID = nil
                dragDX = 0
                guard let from = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
                let dropX = slots.tabs[from].midX + value.translation.width
                let to = slots.tabs.enumerated().filter { $0.offset != from && $0.element.midX < dropX }.count
                model.layout.moveTab(from: from, to: to)
            }
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(white: 0.8))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(red: 0.11, green: 0.11, blue: 0.13)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func textButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(filled ? Color.black : Color.white)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(filled ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.13)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
