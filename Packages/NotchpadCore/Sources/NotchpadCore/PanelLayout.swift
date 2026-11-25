import Foundation

/// One tab: a name and the widgets placed on it.
public struct TabPage: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var widgets: [WidgetPlacement]

    public init(id: UUID = UUID(), name: String, widgets: [WidgetPlacement] = []) {
        self.id = id
        self.name = name
        self.widgets = widgets
    }
}

/// Whether a widget can be added to a tab, and why not.
public enum AddCheck: Equatable, Sendable {
    case ok, alreadyOnTab, noRoom

    public var reason: String? {
        switch self {
        case .ok: nil
        case .alreadyOnTab: "Already on this tab"
        case .noRoom: "No room on this tab"
        }
    }
}

/// All tabs, their widgets, and which tab is showing. Saved as JSON.
public struct PanelLayout: Codable, Equatable, Sendable {
    public static let maxTabs = 4
    public static let maxNameLength = 12

    public var version = 1
    public var tabs: [TabPage]
    public var selectedTabID: UUID

    public init(tabs: [TabPage], selectedTabID: UUID) {
        self.tabs = tabs
        self.selectedTabID = selectedTabID
    }

    /// The first-launch layout: one Home tab. Anyone can add more tabs (Reminders, Tailscale, …) in edit mode.
    public static func makeDefault() -> PanelLayout {
        let home = TabPage(name: "Home", widgets: [
            WidgetPlacement(kind: .music, size: .small, column: 0, half: .top),
            WidgetPlacement(kind: .shelf, size: .small, column: 0, half: .bottom),
            WidgetPlacement(kind: .reminders, size: .medium, column: 1, half: .full),
            WidgetPlacement(kind: .nextEvent, size: .small, column: 2, half: .top),
            WidgetPlacement(kind: .focus, size: .small, column: 2, half: .bottom),
        ])
        return PanelLayout(tabs: [home], selectedTabID: home.id)
    }

    // MARK: Tabs

    public var selectedTab: TabPage { tabs.first { $0.id == selectedTabID } ?? tabs[0] }

    public func tab(_ id: UUID) -> TabPage? { tabs.first { $0.id == id } }

    /// Name first (any case), then a 1-based number.
    public func tabIndex(matching arg: String) -> Int? {
        if let i = tabs.firstIndex(where: { $0.name.caseInsensitiveCompare(arg) == .orderedSame }) { return i }
        if let n = Int(arg), n >= 1, n <= tabs.count { return n - 1 }
        return nil
    }

    /// Adds "Tab N" and selects it. Nil when there are already `maxTabs`.
    public mutating func addTab() -> UUID? {
        guard tabs.count < Self.maxTabs else { return nil }
        var n = 1
        while !isNameFree("Tab \(n)", except: nil) { n += 1 }
        let tab = TabPage(name: "Tab \(n)")
        tabs.append(tab)
        selectedTabID = tab.id
        return tab.id
    }

    public mutating func renameTab(_ id: UUID, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxNameLength,
              isNameFree(trimmed, except: id), let i = index(of: id) else { return false }
        tabs[i].name = trimmed
        return true
    }

    /// Refuses to delete the last tab. Deleting the selected tab selects its neighbour.
    public mutating func deleteTab(_ id: UUID) -> Bool {
        guard tabs.count > 1, let i = index(of: id) else { return false }
        tabs.remove(at: i)
        if selectedTabID == id { selectedTabID = tabs[min(i, tabs.count - 1)].id }
        return true
    }

    public mutating func moveTab(from: Int, to: Int) {
        guard tabs.indices.contains(from), tabs.indices.contains(to), from != to else { return }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
    }

    public func firstTab(containing kind: WidgetKind, size: WidgetSize? = nil) -> UUID? {
        tabs.first { $0.widgets.contains { $0.kind == kind && (size == nil || $0.size == size) } }?.id
    }

    // MARK: Widgets

    public func canAdd(_ kind: WidgetKind, size: WidgetSize, toTab id: UUID) -> AddCheck {
        guard let tab = tab(id) else { return .noRoom }
        if tab.widgets.contains(where: { $0.kind == kind }) { return .alreadyOnTab }
        guard kind.sizes.contains(size), WidgetGrid.firstFreeSpot(for: size, among: tab.widgets) != nil else { return .noRoom }
        return .ok
    }

    /// Adds at the first free spot.
    public mutating func addWidget(_ kind: WidgetKind, size: WidgetSize, toTab id: UUID) -> Bool {
        guard canAdd(kind, size: size, toTab: id) == .ok, let i = index(of: id),
              let spot = WidgetGrid.firstFreeSpot(for: size, among: tabs[i].widgets) else { return false }
        tabs[i].widgets.append(WidgetPlacement(kind: kind, size: size, column: spot.column, half: spot.half))
        return true
    }

    /// Edit mode: a widget dropped on another tab's name moves there, same size, first free spot.
    /// Nothing changes unless the move works.
    public mutating func moveWidget(_ widgetID: UUID, fromTab source: UUID, toTab target: UUID) -> AddCheck {
        guard source != target else { return .alreadyOnTab }
        guard let si = index(of: source), let ti = index(of: target),
              let w = tabs[si].widgets.first(where: { $0.id == widgetID }) else { return .noRoom }
        if tabs[ti].widgets.contains(where: { $0.kind == w.kind }) { return .alreadyOnTab }
        guard let spot = WidgetGrid.firstFreeSpot(for: w.size, among: tabs[ti].widgets) else { return .noRoom }
        tabs[si].widgets.removeAll { $0.id == widgetID }
        tabs[ti].widgets.append(WidgetPlacement(id: w.id, kind: w.kind, size: w.size, column: spot.column, half: spot.half))
        return .ok
    }

    public enum AddResult: Equatable, Sendable {
        case added(UUID)
        /// The tab was full, so a new tab was made for it (and selected).
        case addedToNewTab(UUID)
        case refused(AddCheck)
    }

    /// Gallery click: add to the tab on screen; if it's full, put the widget on a new tab (up to `maxTabs`).
    public mutating func addWidgetOrNewTab(_ kind: WidgetKind, size: WidgetSize, preferring id: UUID) -> AddResult {
        switch canAdd(kind, size: size, toTab: id) {
        case .ok:
            return addWidget(kind, size: size, toTab: id) ? .added(id) : .refused(.noRoom)
        case .alreadyOnTab:
            return .refused(.alreadyOnTab)
        case .noRoom:
            guard kind.sizes.contains(size), let newTab = addTab() else { return .refused(.noRoom) }
            guard addWidget(kind, size: size, toTab: newTab) else { _ = deleteTab(newTab); selectedTabID = id; return .refused(.noRoom) }
            return .addedToNewTab(newTab)
        }
    }

    public mutating func removeWidget(_ widgetID: UUID, fromTab id: UUID) {
        guard let i = index(of: id) else { return }
        tabs[i].widgets.removeAll { $0.id == widgetID }
    }

    public func canResize(_ widgetID: UUID, to size: WidgetSize, inTab id: UUID) -> Bool {
        resized(widgetID, to: size, inTab: id) != nil
    }

    /// Keeps the column. Small takes the top half, or the bottom if the top is taken.
    public mutating func resizeWidget(_ widgetID: UUID, to size: WidgetSize, inTab id: UUID) -> Bool {
        guard let (i, w, placement) = resized(widgetID, to: size, inTab: id) else { return false }
        tabs[i].widgets[w] = placement
        return true
    }

    /// Moves into an empty spot, or swaps with the one widget already there if both fit.
    public mutating func moveWidget(_ widgetID: UUID, toColumn column: Int, half: SlotHalf, inTab id: UUID) -> Bool {
        guard let i = index(of: id), let w = tabs[i].widgets.firstIndex(where: { $0.id == widgetID }) else { return false }
        var widgets = tabs[i].widgets
        let moving = widgets[w]
        let targetHalf: SlotHalf = moving.size == .small ? half : .full
        guard let target = WidgetGrid.cells(size: moving.size, column: column, half: targetHalf) else { return false }
        let others = widgets.indices.filter { j in
            j != w && !(WidgetGrid.cells(of: widgets[j])?.isDisjoint(with: target) ?? true)
        }
        guard others.count <= 1 else { return false }
        widgets[w].column = column
        widgets[w].half = targetHalf
        if let j = others.first {
            widgets[j].column = moving.column
            if widgets[j].size == .small {
                widgets[j].half = moving.half == .full ? .top : moving.half
            } else {
                widgets[j].half = .full
            }
        }
        guard Self.noOverlaps(widgets) else { return false }
        tabs[i].widgets = widgets
        return true
    }

    // MARK: Helpers

    private func index(of id: UUID) -> Int? { tabs.firstIndex { $0.id == id } }

    private func isNameFree(_ name: String, except id: UUID?) -> Bool {
        !tabs.contains { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func resized(_ widgetID: UUID, to size: WidgetSize, inTab id: UUID) -> (Int, Int, WidgetPlacement)? {
        guard let i = index(of: id), let w = tabs[i].widgets.firstIndex(where: { $0.id == widgetID }) else { return nil }
        var p = tabs[i].widgets[w]
        guard p.kind.sizes.contains(size) else { return nil }
        let others = tabs[i].widgets
        let halves: [SlotHalf] = size == .small ? [.top, .bottom] : [.full]
        // Stay in the widget's column if possible; otherwise slide left (never so far that the
        // widget leaves its old column), e.g. Wide from column 2 moves to column 1.
        let columns = stride(from: p.column, through: 0, by: -1).filter { $0 + size.columns > p.column }
        var found: (Int, SlotHalf)?
        for column in columns {
            if let half = halves.first(where: {
                WidgetGrid.fits(size: size, column: column, half: $0, among: others, ignoring: widgetID)
            }) { found = (column, half); break }
        }
        guard let (column, half) = found else { return nil }
        p.size = size
        p.column = column
        p.half = half
        return (i, w, p)
    }

    static func noOverlaps(_ widgets: [WidgetPlacement]) -> Bool {
        var taken = Set<GridCell>()
        for w in widgets {
            guard let cells = WidgetGrid.cells(of: w), cells.isDisjoint(with: taken) else { return false }
            taken.formUnion(cells)
        }
        return true
    }
}

// MARK: Repair and tolerant decoding

extension PanelLayout {
    /// Fixes anything a hand-edited or older file could contain, so the panel never breaks.
    public func validated() -> PanelLayout {
        var fixed: [TabPage] = []
        var seenTabIDs = Set<UUID>()
        var seenWidgetIDs = Set<UUID>()
        for var tab in tabs.prefix(Self.maxTabs) {
            // A copied block keeps its UUID; give repeats fresh ones so every tab and widget is unique.
            if !seenTabIDs.insert(tab.id).inserted { tab.id = UUID() }
            for i in tab.widgets.indices where !seenWidgetIDs.insert(tab.widgets[i].id).inserted {
                tab.widgets[i].id = UUID()
                seenWidgetIDs.insert(tab.widgets[i].id)
            }
            var name = String(tab.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let taken = Set(fixed.map { $0.name.lowercased() })
            if name.isEmpty {
                var n = 1
                while taken.contains("tab \(n)") || tabs.contains(where: { $0.name.lowercased() == "tab \(n)" }) { n += 1 }
                name = "Tab \(n)"
            }
            if taken.contains(name.lowercased()) {
                var n = 2
                func candidate(_ n: Int) -> String {
                    let suffix = " \(n)"
                    return String(name.prefix(Self.maxNameLength - suffix.count)).trimmingCharacters(in: .whitespaces) + suffix
                }
                while taken.contains(candidate(n).lowercased()) { n += 1 }
                name = candidate(n)
            }
            tab.name = name

            var kept: [WidgetPlacement] = []
            for w in tab.widgets where w.kind.sizes.contains(w.size)
                && !kept.contains(where: { $0.kind == w.kind })
                && Self.noOverlaps(kept + [w]) {
                kept.append(w)
            }
            tab.widgets = kept
            fixed.append(tab)
        }
        guard !fixed.isEmpty else { return .makeDefault() }
        var result = PanelLayout(tabs: fixed, selectedTabID: selectedTabID)
        if !fixed.contains(where: { $0.id == selectedTabID }) { result.selectedTabID = fixed[0].id }
        return result
    }

    private enum CodingKeys: String, CodingKey { case version, tabs, selectedTabID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tabs = try c.decode([TabPage].self, forKey: .tabs)
        selectedTabID = (try? c.decode(UUID.self, forKey: .selectedTabID)) ?? tabs.first?.id ?? UUID()
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
    }
}

extension TabPage {
    private enum CodingKeys: String, CodingKey { case id, name, widgets }

    /// Skips widgets it can't read (e.g. a kind from a newer version) instead of failing the whole file.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        widgets = ((try? c.decode([Lossy<WidgetPlacement>].self, forKey: .widgets)) ?? []).compactMap(\.value)
    }
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
