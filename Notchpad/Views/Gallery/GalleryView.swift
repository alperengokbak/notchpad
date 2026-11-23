import NotchpadCore
import SwiftUI

/// The "Add widget" sheet, modelled on the macOS widget gallery: sidebar with search and
/// categories, previews on demo data, click a preview to add it to the tab on screen.
struct GalleryView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var category: WidgetCategory?
    @State private var hovered: String?

    private static let previewScale: CGFloat = 0.5
    private static let area = CGSize(width: 636, height: 146)

    private var kinds: [WidgetKind] {
        WidgetKind.allCases.filter { kind in
            (category == nil || kind.category == category)
                && (query.isEmpty || kind.title.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        let _ = DebugTools.log("gallery body")
        let inputs = DemoData.inputs(now: Date())
        HStack(spacing: 0) {
            sidebar.frame(width: 180)
            Rectangle().fill(Color(white: 0.18)).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(category?.title ?? (query.isEmpty ? "All widgets" : "Results"))
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(white: 0.75))
                        if kinds.isEmpty {
                            Text("No widgets match “\(query)”").font(.system(size: 12)).foregroundStyle(Color(white: 0.5))
                        }
                        ForEach(kinds, id: \.self) { kind in section(kind, inputs: inputs) }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
        }
        .frame(width: 700, height: 420)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.09)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(white: 0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(Color(white: 0.5))
                TextField("Search widgets", text: $query).textFieldStyle(.plain).font(.system(size: 12))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.15)))
            .padding(.bottom, 10)
            sidebarRow("All widgets", symbol: "square.grid.2x2", selected: category == nil) { category = nil }
            ForEach(WidgetCategory.allCases, id: \.self) { c in
                sidebarRow(c.title, symbol: symbol(for: c), selected: category == c) { category = c }
            }
            Spacer()
        }
        .padding(14)
    }

    private func symbol(for c: WidgetCategory) -> String {
        switch c {
        case .media: "play.rectangle"
        case .productivity: "checklist"
        case .network: "network"
        }
    }

    private func sidebarRow(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 12)).frame(width: 18)
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Color(white: 0.2) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Previews

    private func section(_ kind: WidgetKind, inputs: WidgetInputs) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol).font(.system(size: 11))
                Text(kind.title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color(white: 0.85))
            FlowLayout(spacing: 12) {
                ForEach(kind.sizes, id: \.self) { size in tile(kind, size, inputs: inputs) }
            }
        }
    }

    private func tile(_ kind: WidgetKind, _ size: WidgetSize, inputs: WidgetInputs) -> some View {
        let check = model.layout.canAdd(kind, size: size, toTab: model.selectedTabID)
        let real = WidgetGrid.frame(size: size, column: 0, half: size == .small ? .top : .full, in: Self.area, gap: 10).size
        let shown = CGSize(width: real.width * Self.previewScale, height: real.height * Self.previewScale)
        let key = "\(kind.rawValue)-\(size.rawValue)"
        return VStack(alignment: .leading, spacing: 5) {
            WidgetView(kind: kind, size: size, inputs: inputs)
                .frame(width: real.width, height: real.height)
                .scaleEffect(Self.previewScale, anchor: .topLeading)
                .frame(width: shown.width, height: shown.height, alignment: .topLeading)
                .allowsHitTesting(false)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(hovered == key && check == .ok ? Color.white : Color(white: 0.2), lineWidth: 1))
            Text(size.title).font(.system(size: 10)).foregroundStyle(Color(white: 0.55))
        }
        .opacity(check == .ok ? 1 : 0.35)
        .contentShape(Rectangle())
        .onHover { hovered = $0 ? key : (hovered == key ? nil : hovered) }
        .onTapGesture {
            guard check == .ok else { return }
            if model.layout.addWidget(kind, size: size, toTab: model.selectedTabID) {
                DebugTools.log("added: \(kind.rawValue) \(size.rawValue)")
            }
        }
        .help(check.reason ?? "Add \(kind.title) (\(size.title)) to \(model.layout.selectedTab.name)")
    }

    private var footer: some View {
        HStack {
            Text("Click a widget to add it to \(model.layout.selectedTab.name)")
                .font(.system(size: 11)).foregroundStyle(Color(white: 0.55))
            Spacer()
            Button { model.showGallery = false } label: {
                Text("Done").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor)).contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color(white: 0.11))
    }
}

/// Lays children out left to right, wrapping to a new row when the width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
