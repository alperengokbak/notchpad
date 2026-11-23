import Foundation
import Testing
@testable import NotchpadCore

private extension PanelLayout {
    func id(_ name: String) -> UUID { tabs.first { $0.name == name }!.id }
    func widget(_ kind: WidgetKind, on name: String) -> WidgetPlacement? {
        tab(id(name))?.widgets.first { $0.kind == kind }
    }
}

private func spot(_ p: WidgetPlacement?) -> String {
    guard let p else { return "-" }
    return "\(p.kind.rawValue) \(p.size.rawValue) c\(p.column) \(p.half.rawValue)"
}

@Test func defaultMatchesTodaysLayout() {
    let l = PanelLayout.makeDefault()
    #expect(l.tabs.map(\.name) == ["Home", "Reminders", "Tailscale"])
    #expect(l.tabs[0].widgets.map(spot) == [
        "music small c0 top", "shelf small c0 bottom", "reminders medium c1 full",
        "nextEvent small c2 top", "focus small c2 bottom",
    ])
    #expect(l.tabs[1].widgets.map(spot) == ["reminders full c0 full"])
    #expect(l.tabs[2].widgets.map(spot) == ["tailscale full c0 full"])
    #expect(l.selectedTabID == l.tabs[0].id)
}

@Test func addTabNamesAndLimit() {
    var l = PanelLayout.makeDefault()
    let new = l.addTab()
    #expect(new != nil)
    #expect(l.tabs.last?.name == "Tab 1")
    #expect(l.selectedTabID == new)
    do { let r = l.addTab(); #expect(r == nil) }
    #expect(l.tabs.count == 4)
}

@Test func renameRejectsBadNames() {
    var l = PanelLayout.makeDefault()
    let home = l.id("Home")
    for bad in ["", "   ", "ThirteenChars", "reminders"] {
        do { let r = l.renameTab(home, to: bad); #expect(!r) }
        #expect(l.tab(home)?.name == "Home")
    }
    do { let r = l.renameTab(home, to: "  Study  "); #expect(r) }
    #expect(l.tab(home)?.name == "Study")
    do { let r = l.renameTab(home, to: "study"); #expect(r) }  // same tab, different case is fine
}

@Test func deleteSelectedTabSelectsNeighbour() {
    var l = PanelLayout.makeDefault()
    l.selectedTabID = l.id("Tailscale")
    do { let r = l.deleteTab(l.id("Tailscale")); #expect(r) }
    #expect(l.selectedTab.name == "Reminders")
    l.selectedTabID = l.id("Home")
    do { let r = l.deleteTab(l.id("Home")); #expect(r) }
    #expect(l.selectedTab.name == "Reminders")
}

@Test func cannotDeleteLastTab() {
    var l = PanelLayout.makeDefault()
    do { let r = l.deleteTab(l.id("Home")); #expect(r) }
    do { let r = l.deleteTab(l.id("Reminders")); #expect(r) }
    do { let r = l.deleteTab(l.id("Tailscale")); #expect(!r) }
    #expect(l.tabs.count == 1)
}

@Test func canAddReasons() {
    var l = PanelLayout.makeDefault()
    #expect(l.canAdd(.music, size: .small, toTab: l.id("Home")) == .alreadyOnTab)
    #expect(l.canAdd(.tailscale, size: .medium, toTab: l.id("Home")) == .noRoom)
    #expect(l.canAdd(.music, size: .small, toTab: l.id("Reminders")) == .noRoom)
    let empty = l.addTab()!
    #expect(l.canAdd(.tailscale, size: .full, toTab: empty) == .ok)
    #expect(l.canAdd(.focus, size: .medium, toTab: empty) == .noRoom)  // unsupported size
    #expect(AddCheck.alreadyOnTab.reason == "Already on this tab")
    #expect(AddCheck.noRoom.reason == "No room on this tab")
    #expect(AddCheck.ok.reason == nil)
}

@Test func addWidgetUsesFirstFreeSpot() {
    var l = PanelLayout.makeDefault()
    let t = l.addTab()!
    do { let r = l.addWidget(.music, size: .small, toTab: t); #expect(r) }
    do { let r = l.addWidget(.focus, size: .small, toTab: t); #expect(r) }
    do { let r = l.addWidget(.reminders, size: .wide, toTab: t); #expect(r) }
    #expect(l.tab(t)!.widgets.map(spot) == ["music small c0 top", "focus small c0 bottom", "reminders wide c1 full"])
    do { let r = l.addWidget(.shelf, size: .small, toTab: t); #expect(!r) }
    do { let r = l.addWidget(.music, size: .small, toTab: t); #expect(!r) }
}

@Test func removeWidget() {
    var l = PanelLayout.makeDefault()
    let home = l.id("Home")
    let focus = l.widget(.focus, on: "Home")!
    l.removeWidget(focus.id, fromTab: home)
    #expect(l.widget(.focus, on: "Home") == nil)
    #expect(l.tab(home)!.widgets.count == 4)
}

@Test func resizeKeepsColumnOrRefuses() {
    var l = PanelLayout.makeDefault()
    let home = l.id("Home")
    let reminders = l.widget(.reminders, on: "Home")!
    #expect(!l.canResize(reminders.id, to: .wide, inTab: home))
    do { let r = l.resizeWidget(reminders.id, to: .wide, inTab: home); #expect(!r) }
    #expect(!l.canResize(reminders.id, to: .small, inTab: home))

    let t = l.addTab()!
    do { let r = l.addWidget(.reminders, size: .medium, toTab: t); #expect(r) }
    let r = l.tab(t)!.widgets[0]
    do { let r = l.resizeWidget(r.id, to: .wide, inTab: t); #expect(r) }
    #expect(spot(l.tab(t)!.widgets[0]) == "reminders wide c0 full")
    do { let r = l.resizeWidget(r.id, to: .full, inTab: t); #expect(r) }
    #expect(spot(l.tab(t)!.widgets[0]) == "reminders full c0 full")
}

@Test func resizeToSmallPicksFreeHalf() {
    var l = PanelLayout.makeDefault()
    let t = l.addTab()!
    do { let r = l.addWidget(.music, size: .medium, toTab: t); #expect(r) }
    let m = l.tab(t)!.widgets[0]
    do { let r = l.resizeWidget(m.id, to: .small, inTab: t); #expect(r) }
    #expect(spot(l.tab(t)!.widgets[0]) == "music small c0 top")
}

@Test func moveIntoEmptySpot() {
    var l = PanelLayout.makeDefault()
    let t = l.addTab()!
    do { let r = l.addWidget(.music, size: .small, toTab: t); #expect(r) }
    let m = l.tab(t)!.widgets[0]
    do { let r = l.moveWidget(m.id, toColumn: 2, half: .bottom, inTab: t); #expect(r) }
    #expect(spot(l.tab(t)!.widgets[0]) == "music small c2 bottom")
}

@Test func moveSwaps() {
    var l = PanelLayout.makeDefault()
    let next = l.widget(.nextEvent, on: "Home")!
    do { let r = l.moveWidget(next.id, toColumn: 0, half: .top, inTab: l.id("Home")); #expect(r) }
    #expect(spot(l.widget(.nextEvent, on: "Home")) == "nextEvent small c0 top")
    #expect(spot(l.widget(.music, on: "Home")) == "music small c2 top")
}

@Test func moveSwapRefusedWhenItCannotFit() {
    var l = PanelLayout.makeDefault()
    let before = l
    let reminders = l.widget(.reminders, on: "Home")!
    do { let r = l.moveWidget(reminders.id, toColumn: 0, half: .full, inTab: l.id("Home")); #expect(!r) }
    #expect(l == before)
}

@Test func moveSwapsMediumWithMedium() {
    var l = PanelLayout.makeDefault()
    let t = l.addTab()!
    do { let r = l.addWidget(.reminders, size: .medium, toTab: t); #expect(r) }
    do { let r = l.addWidget(.tailscale, size: .medium, toTab: t); #expect(r) }
    let r = l.tab(t)!.widgets[0]
    do { let ok = l.moveWidget(r.id, toColumn: 1, half: .top, inTab: t); #expect(ok) }  // non-Small target becomes .full
    #expect(l.tab(t)!.widgets.map(spot) == ["reminders medium c1 full", "tailscale medium c0 full"])
}

@Test func moveTabReorders() {
    var l = PanelLayout.makeDefault()
    l.moveTab(from: 2, to: 0)
    #expect(l.tabs.map(\.name) == ["Tailscale", "Home", "Reminders"])
}

@Test func tabIndexMatching() {
    let l = PanelLayout.makeDefault()
    #expect(l.tabIndex(matching: "tailscale") == 2)
    #expect(l.tabIndex(matching: "TAILSCALE") == 2)
    #expect(l.tabIndex(matching: "2") == 1)
    #expect(l.tabIndex(matching: "9") == nil)
    #expect(l.tabIndex(matching: "nope") == nil)
}

@Test func firstTabContaining() {
    let l = PanelLayout.makeDefault()
    #expect(l.firstTab(containing: .reminders) == l.id("Home"))
    #expect(l.firstTab(containing: .reminders, size: .full) == l.id("Reminders"))
    #expect(l.firstTab(containing: .tailscale, size: .medium) == nil)
}
