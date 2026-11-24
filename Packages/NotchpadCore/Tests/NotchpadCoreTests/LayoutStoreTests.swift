import Foundation
import Testing
@testable import NotchpadCore

private func tempFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("notchpad-layout-tests-\(UUID().uuidString)/layout.json")
}

private func write(_ json: String, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? Data(json.utf8).write(to: url)
}

private func shape(_ l: PanelLayout) -> [String] {
    l.tabs.map { "\($0.name): " + $0.widgets.map(\.kind.rawValue).joined(separator: ",") }
}

@Test func missingFileGivesDefault() {
    let store = LayoutStore(fileURL: tempFile())
    let l = store.load()
    #expect(shape(l) == shape(.makeDefault()))
    #expect(!store.lastLoadFailed)
}

@Test func roundTrip() {
    let url = tempFile()
    var l = PanelLayout.makeDefault()
    let ok = l.renameTab(l.tabs[0].id, to: "Study")
    #expect(ok)
    _ = l.addTab()
    LayoutStore(fileURL: url).save(l)
    #expect(LayoutStore(fileURL: url).load() == l)
}

@Test func unknownWidgetKindIsDropped() {
    let url = tempFile()
    let tab = UUID()
    write("""
    {"version":1,"selectedTabID":"\(tab)","tabs":[{"id":"\(tab)","name":"Mine","widgets":[
      {"id":"\(UUID())","kind":"music","size":"small","column":0,"half":"top"},
      {"id":"\(UUID())","kind":"weather","size":"small","column":1,"half":"top"}
    ]}]}
    """, to: url)
    let store = LayoutStore(fileURL: url)
    #expect(shape(store.load()) == ["Mine: music"])
    #expect(!store.lastLoadFailed)
}

@Test func corruptFileFallsBackToDefault() {
    let url = tempFile()
    write("{nope", to: url)
    let store = LayoutStore(fileURL: url)
    #expect(shape(store.load()) == shape(.makeDefault()))
    #expect(store.lastLoadFailed)
}

@Test func validatedRepairsBrokenLayout() {
    let names = ["", "Home", "home", "A very long tab name indeed", "Five", "Six"]
    var tabs = names.map { TabPage(name: $0) }
    tabs[1].widgets = [
        WidgetPlacement(kind: .reminders, size: .medium, column: 1, half: .full),
        WidgetPlacement(kind: .focus, size: .small, column: 1, half: .top),      // overlaps Reminders
        WidgetPlacement(kind: .music, size: .small, column: 0, half: .top),
        WidgetPlacement(kind: .music, size: .small, column: 2, half: .top),      // second Music
        WidgetPlacement(kind: .focus, size: .medium, column: 2, half: .full),    // unsupported size
        WidgetPlacement(kind: .shelf, size: .full, column: 1, half: .full),      // invalid spot
    ]
    let l = PanelLayout(tabs: tabs, selectedTabID: UUID()).validated()
    #expect(l.tabs.count == 4)
    #expect(l.tabs.allSatisfy { !$0.name.isEmpty && $0.name.count <= PanelLayout.maxNameLength })
    #expect(Set(l.tabs.map { $0.name.lowercased() }).count == 4)
    #expect(l.tabs[1].name == "Home")
    #expect(l.tabs[1].widgets.map(\.kind) == [.reminders, .music])
    #expect(l.selectedTabID == l.tabs[0].id)
}

@Test func validatedKeepsAGoodLayoutUnchanged() {
    let l = PanelLayout.makeDefault()
    #expect(l.validated() == l)
}

@Test func emptyTabsListGivesDefault() {
    let url = tempFile()
    write(#"{"version":1,"tabs":[],"selectedTabID":"\#(UUID())"}"#, to: url)
    #expect(shape(LayoutStore(fileURL: url).load()) == shape(.makeDefault()))
}

@Test func validatedGivesDuplicateIDsFreshOnes() {
    let tabID = UUID(), widgetID = UUID()
    let a = TabPage(id: tabID, name: "A", widgets: [
        WidgetPlacement(id: widgetID, kind: .music, size: .small, column: 0, half: .top),
        WidgetPlacement(id: widgetID, kind: .focus, size: .small, column: 0, half: .bottom),
    ])
    let b = TabPage(id: tabID, name: "B", widgets: [
        WidgetPlacement(id: widgetID, kind: .music, size: .small, column: 0, half: .top),
    ])
    let l = PanelLayout(tabs: [a, b], selectedTabID: tabID).validated()
    #expect(l.tabs.count == 2)
    #expect(Set(l.tabs.map(\.id)).count == 2)
    let widgetIDs = l.tabs.flatMap(\.widgets).map(\.id)
    #expect(widgetIDs.count == 3)
    #expect(Set(widgetIDs).count == 3)
    #expect(l.tabs[0].id == tabID)
    #expect(l.selectedTabID == tabID)
}

@Test func brokenFileIsKeptAsBackup() throws {
    let url = tempFile()
    write("not json", to: url)
    let store = LayoutStore(fileURL: url)
    let l = store.load()
    #expect(shape(l) == shape(.makeDefault()))
    #expect(store.lastLoadFailed)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    let backup = try #require(store.lastBackupURL)
    #expect(backup.deletingLastPathComponent() == url.deletingLastPathComponent())
    #expect(backup.lastPathComponent.hasPrefix("layout-broken-") && backup.pathExtension == "json")
    #expect(try Data(contentsOf: backup) == Data("not json".utf8))
}

@Test func storeUsesInjectedDefault() {
    let store = LayoutStore(fileURL: tempFile(), makeDefault: { .threeTabs() })
    #expect(store.load().tabs.map(\.name) == ["Home", "Reminders", "Tailscale"])
}
