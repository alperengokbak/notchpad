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
    /// Clicking the title opens the editor.
    var onEdit: () -> Void = {}
    /// Trash on hover (nil = no trash, e.g. gallery previews).
    var onDelete: (() -> Void)?

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onTick) {
                Image(systemName: pending ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(pending ? Color.orange : Color(white: 0.55))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: onEdit) {
                HStack(spacing: 4) {
                    Text(reminder.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        .strikethrough(pending).foregroundStyle(pending ? Color(white: 0.5) : .white)
                    Spacer(minLength: 4)
                    if let label, !(hovering && onDelete != nil) {
                        Text(label).font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isOverdue ? Color.red : Color(white: 0.55))
                            .lineLimit(1).fixedSize()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit")
            if let onDelete { HoverDelete(rowHovered: hovering, onDelete: onDelete) }
        }
        .onHover { hovering = $0 }
    }
}

/// Trash on a hovered row. The first click asks ("Delete"), the second deletes, because a deleted
/// reminder or event can't be brought back. Leaving the row or waiting 3 seconds cancels.
struct HoverDelete: View {
    let rowHovered: Bool
    let onDelete: () -> Void

    @State private var confirming = false
    @State private var token = 0

    var body: some View {
        Group {
            if confirming {
                Button {
                    confirming = false
                    onDelete()
                } label: {
                    Text("Delete").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color.red)).contentShape(Capsule())
                }
                .help("Click again to delete")
            } else if rowHovered {
                Button {
                    confirming = true
                    DebugTools.log("delete: asking")
                    token += 1
                    let mine = token
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { if token == mine { confirming = false } }
                } label: {
                    Image(systemName: "trash").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(white: 0.6))
                        .frame(width: 18, height: 16).contentShape(Rectangle())
                }
                .help("Delete")
            }
        }
        .buttonStyle(.plain)
        .onChange(of: rowHovered) { _, hovered in if !hovered { confirming = false } }
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
    let inputs: WidgetInputs

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button { inputs.actions.openFullReminders() } label: {
                HStack(spacing: 3) {
                    Text("REMINDERS").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(Color(white: 0.55)).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                if inputs.remindersAccess == .granted { AddButton(help: "New reminder") { inputs.actions.newReminder() } }
            }
            switch inputs.remindersAccess {
            case .denied: accessOff()
            case .unknown: EmptyView()
            case .granted:
                let items = ReminderLogic.scrollList(inputs.reminders, now: inputs.now, calendar: .current)
                if items.isEmpty {
                    Text("No reminders").font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
                } else {
                    // Every reminder; the header stays put and the list scrolls under it.
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(items) { r in
                                ReminderRow(reminder: r,
                                            label: ReminderLogic.dueLabel(r, now: inputs.now, calendar: .current),
                                            isOverdue: ReminderLogic.isOverdue(r, now: inputs.now, calendar: .current),
                                            pending: inputs.pendingReminderIDs.contains(r.id),
                                            onTick: { inputs.actions.tickReminder(r.id) },
                                            onEdit: { inputs.actions.editReminder(r.id) },
                                    onDelete: { inputs.actions.deleteReminder(r.id) })
                            }
                        }
                        .padding(.bottom, 2)
                    }
                    .scrollIndicators(.automatic)
                }
            }
        }
    }
}

/// The Reminders tab: every open reminder, grouped by list.
struct RemindersTab: View {
    let inputs: WidgetInputs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("REMINDERS").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    .foregroundStyle(Color(white: 0.55))
                Spacer()
                if inputs.remindersAccess == .granted {
                    AddButton(help: "New reminder") { inputs.actions.newReminder() }.padding(.trailing, 6)
                }
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
            if inputs.remindersAccess == .denied {
                accessOff()
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(ReminderLogic.grouped(inputs.reminders), id: \.listTitle) { group in
                            Text(group.listTitle).font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(white: 0.5)).padding(.top, 3)
                            ForEach(group.items) { r in
                                ReminderRow(reminder: r,
                                            label: ReminderLogic.dueLabel(r, now: inputs.now, calendar: .current),
                                            isOverdue: ReminderLogic.isOverdue(r, now: inputs.now, calendar: .current),
                                            pending: inputs.pendingReminderIDs.contains(r.id),
                                            onTick: { inputs.actions.tickReminder(r.id) },
                                    onEdit: { inputs.actions.editReminder(r.id) },
                                    onDelete: { inputs.actions.deleteReminder(r.id) })
                            }
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
        }
    }
}

/// The small "+" in a widget header.
struct AddButton: View {
    var help = "Add"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(white: 0.75))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color(white: 0.18)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
