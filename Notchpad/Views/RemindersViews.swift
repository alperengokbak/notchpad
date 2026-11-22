import AppKit
import NotchpadCore
import SwiftUI

/// One reminder: tick circle, title, due label.
struct ReminderRow: View {
    let reminder: ReminderSummary
    let label: String?
    let isOverdue: Bool
    let pending: Bool
    let onTick: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onTick) {
                Image(systemName: pending ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(pending ? Color.orange : Color(white: 0.55))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(reminder.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                .strikethrough(pending).foregroundStyle(pending ? Color(white: 0.5) : .white)
            Spacer(minLength: 4)
            if let label {
                Text(label).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isOverdue ? Color.red : Color(white: 0.55))
                    .lineLimit(1).fixedSize()
            }
        }
    }
}

private func accessOff() -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("Reminders access is off").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
        Button("Open Settings") {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
        }
        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
    }
}

/// Home, middle column: the reminders due soonest. Clicking the header opens the Reminders tab.
struct RemindersSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button { model.selectedTab = .reminders } label: {
                HStack(spacing: 3) {
                    Text("REMINDERS").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(Color(white: 0.55)).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            switch model.remindersAccess {
            case .denied: accessOff()
            case .unknown: EmptyView()
            case .granted:
                let items = ReminderLogic.homeList(model.reminders, now: model.clock, calendar: .current)
                if items.isEmpty {
                    Text("No reminders due").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                } else {
                    ForEach(items) { r in
                        ReminderRow(reminder: r,
                                    label: ReminderLogic.dueLabel(r, now: model.clock, calendar: .current),
                                    isOverdue: ReminderLogic.isOverdue(r, now: model.clock, calendar: .current),
                                    pending: model.pendingReminderIDs.contains(r.id),
                                    onTick: { model.toggleReminder(r.id) })
                    }
                }
            }
        }
    }
}

/// The Reminders tab: every open reminder, grouped by list.
struct RemindersTab: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("REMINDERS").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    .foregroundStyle(Color(white: 0.55))
                Spacer()
                Button {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
                        NSWorkspace.shared.openApplication(at: url, configuration: .init())
                    }
                } label: {
                    Text("Open Reminders").font(.system(size: 11, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 3)
                        .background(Capsule().fill(Color.white)).contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if model.remindersAccess == .denied {
                accessOff()
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(ReminderLogic.grouped(model.reminders), id: \.listTitle) { group in
                            Text(group.listTitle).font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(white: 0.5)).padding(.top, 3)
                            ForEach(group.items) { r in
                                ReminderRow(reminder: r,
                                            label: ReminderLogic.dueLabel(r, now: model.clock, calendar: .current),
                                            isOverdue: ReminderLogic.isOverdue(r, now: model.clock, calendar: .current),
                                            pending: model.pendingReminderIDs.contains(r.id),
                                            onTick: { model.toggleReminder(r.id) })
                            }
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
        }
    }
}
