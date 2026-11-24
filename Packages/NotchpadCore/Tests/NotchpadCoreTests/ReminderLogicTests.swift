import Foundation
import Testing
@testable import NotchpadCore

private var london: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/London")!
    return c
}
private func at(_ day: Int, _ h: Int = 0, _ m: Int = 0) -> Date {
    london.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))!
}
private let now = at(22, 14, 0) // Sunday 22 Nov 2026, 14:00

private func r(_ title: String, due: Date?, time: Bool = false, list: Int = 0, listTitle: String = "Personel") -> ReminderSummary {
    ReminderSummary(id: title, title: title, listID: "L\(list)", listTitle: listTitle, listOrder: list, due: due, dueHasTime: time)
}

@Test func dueLabelTimedVsDateOnly() {
    #expect(ReminderLogic.dueLabel(r("a", due: at(22, 9), time: true), now: now, calendar: london) == "Overdue")
    #expect(ReminderLogic.dueLabel(r("b", due: at(22, 18), time: true), now: now, calendar: london) == "Today")
    #expect(ReminderLogic.dueLabel(r("c", due: at(22)), now: now, calendar: london) == "Today")
    #expect(ReminderLogic.dueLabel(r("d", due: at(21)), now: now, calendar: london) == "Overdue")
    #expect(ReminderLogic.isOverdue(r("a", due: at(22, 9), time: true), now: now, calendar: london))
    #expect(!ReminderLogic.isOverdue(r("c", due: at(22)), now: now, calendar: london))
}

@Test func labelsTomorrowWeekdayDate() {
    #expect(ReminderLogic.dueLabel(r("a", due: at(23)), now: now, calendar: london) == "Tomorrow")
    #expect(ReminderLogic.dueLabel(r("b", due: at(24)), now: now, calendar: london) == "Tue")
    #expect(ReminderLogic.dueLabel(r("c", due: at(28)), now: now, calendar: london) == "Sat")
    #expect(ReminderLogic.dueLabel(r("d", due: london.date(from: DateComponents(year: 2026, month: 12, day: 3))!), now: now, calendar: london) == "3 Dec")
    #expect(ReminderLogic.dueLabel(r("e", due: nil), now: now, calendar: london) == nil)
}

@Test func homeListDatedOnlyOverdueFirstLimit4() {
    let items = [r("later", due: at(25)), r("undated", due: nil), r("overdueOld", due: at(20)),
                 r("todayTimed", due: at(22, 16), time: true), r("overdueTimed", due: at(22, 9), time: true),
                 r("tomorrow", due: at(23))]
    #expect(ReminderLogic.homeList(items, now: now, calendar: london).map(\.title)
            == ["overdueOld", "overdueTimed", "todayTimed", "tomorrow"])
}

@Test func groupedByListOrderDatedThenUndated() {
    let items = [r("idea", due: nil, list: 1, listTitle: "Projects ideas"),
                 r("u1", due: nil, list: 0), r("d2", due: at(25), list: 0), r("d1", due: at(23), list: 0),
                 r("milk", due: nil, list: 2, listTitle: "Shopping")]
    let g = ReminderLogic.grouped(items)
    #expect(g.map(\.listTitle) == ["Personel", "Projects ideas", "Shopping"])
    #expect(g[0].items.map(\.title) == ["d1", "d2", "u1"])
}

@Test func scrollListHasEveryReminderDatedFirstThenUndated() {
    let items = [r("later", due: at(25)), r("undated1", due: nil), r("overdueOld", due: at(20)),
                 r("todayTimed", due: at(22, 16), time: true), r("overdueTimed", due: at(22, 9), time: true),
                 r("tomorrow", due: at(23)), r("undated2", due: nil, list: 1)]
    #expect(ReminderLogic.scrollList(items, now: now, calendar: london).map(\.title)
            == ["overdueOld", "overdueTimed", "todayTimed", "tomorrow", "later", "undated1", "undated2"])
}
