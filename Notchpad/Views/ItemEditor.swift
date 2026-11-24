import AppKit
import NotchpadCore
import SwiftUI

/// The card over the widgets for adding, changing or deleting a reminder or an event.
/// Return saves, Esc cancels. Nothing is written until Save or Delete.
struct ItemEditor: View {
    let item: EditorItem
    let lists: [NamedList]
    let error: String?
    let onSave: (EditorItem) -> Void
    let onDelete: (EditorItem) -> Void
    let onCancel: () -> Void

    @State private var reminder: ReminderDraft
    @State private var event: EventDraft
    @FocusState private var titleFocused: Bool

    init(item: EditorItem, lists: [NamedList], error: String?,
         onSave: @escaping (EditorItem) -> Void, onDelete: @escaping (EditorItem) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.lists = lists
        self.error = error
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        let now = Date()
        switch item {
        case .reminder(let d):
            _reminder = State(initialValue: d)
            _event = State(initialValue: EventDraft.new(calendarID: "", now: now, calendar: .current))
        case .event(let d, _):
            _event = State(initialValue: d)
            _reminder = State(initialValue: ReminderDraft.new(listID: "", now: now, calendar: .current))
        }
    }

    private var isReminder: Bool { if case .reminder = item { true } else { false } }
    private var readOnly: Bool { if case .event(_, let ro) = item { ro } else { false } }
    private var isNew: Bool {
        switch item {
        case .reminder(let d): d.id == nil
        case .event(let d, _): d.id == nil
        }
    }
    private var canSave: Bool { isReminder ? reminder.canSave : event.canSave }
    private var current: EditorItem { isReminder ? .reminder(reminder) : .event(event, readOnly: readOnly) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            if readOnly {
                readOnlyBody
            } else {
                TextField(isReminder ? "Reminder" : "Event title", text: isReminder ? $reminder.title : $event.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.14)))
                    .focused($titleFocused)
                    .onSubmit { if canSave { onSave(current) } }
                if isReminder { reminderDates } else { eventDates }
            }
            Spacer(minLength: 0)
            buttons
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(white: 0.22), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .onExitCommand(perform: onCancel)
        .onAppear { DispatchQueue.main.async { titleFocused = !readOnly } }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(headerTitle).font(.system(size: 10, weight: .medium)).tracking(0.6)
                .foregroundStyle(Color(white: 0.55))
            Spacer()
            if !readOnly && !lists.isEmpty {
                Picker("", selection: isReminder ? $reminder.listID : $event.calendarID) {
                    ForEach(lists) { Text($0.title).tag($0.id) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
            }
        }
    }

    private var headerTitle: String {
        switch (isReminder, isNew, readOnly) {
        case (_, _, true): "EVENT (READ-ONLY CALENDAR)"
        case (true, true, _): "NEW REMINDER"
        case (true, false, _): "EDIT REMINDER"
        case (false, true, _): "NEW EVENT"
        case (false, false, _): "EDIT EVENT"
        }
    }

    private var reminderDates: some View {
        HStack(spacing: 10) {
            Toggle("Due", isOn: $reminder.hasDue).toggleStyle(.checkbox)
            if reminder.hasDue {
                DatePicker("", selection: $reminder.due, displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.field)
                Toggle("Time", isOn: $reminder.hasTime).toggleStyle(.checkbox)
                if reminder.hasTime {
                    DatePicker("", selection: $reminder.due, displayedComponents: .hourAndMinute)
                        .labelsHidden().datePickerStyle(.field)
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .controlSize(.small)
    }

    private var eventDates: some View {
        let parts: DatePickerComponents = event.isAllDay ? .date : [.date, .hourAndMinute]
        let start = Binding(get: { event.start }, set: { event.moveStart(to: $0) })
        return HStack(spacing: 8) {
            DatePicker("", selection: start, displayedComponents: parts)
                .labelsHidden().datePickerStyle(.field)
            Text("to").foregroundStyle(Color(white: 0.55))
            DatePicker("", selection: $event.end, displayedComponents: parts)
                .labelsHidden().datePickerStyle(.field)
            Toggle("All day", isOn: $event.isAllDay).toggleStyle(.checkbox)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .controlSize(.small)
    }

    private var readOnlyBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            Text(event.isAllDay ? "All day" : DayEvents.timeText(
                EventSummary(id: "", title: "", start: event.start, end: event.end, isAllDay: false, red: 0, green: 0, blue: 0),
                calendar: .current))
                .font(.system(size: 12)).foregroundStyle(Color(white: 0.6))
            Text("This calendar can't be changed here.").font(.system(size: 11)).foregroundStyle(Color(white: 0.5))
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            if !isNew && !readOnly {
                Button("Delete") { onDelete(current) }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.red)
            }
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(Color.orange)
            }
            Spacer()
            if !isReminder {
                textButton("Open Calendar") {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                        NSWorkspace.shared.openApplication(at: url, configuration: .init())
                    }
                    onCancel()
                }
            }
            textButton(readOnly ? "Close" : "Cancel", action: onCancel)
            if !readOnly {
                Button { onSave(current) } label: {
                    Text("Save").font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 14).padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(canSave ? 1 : 0.35))).contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(white: 0.8))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color(white: 0.18))).contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
