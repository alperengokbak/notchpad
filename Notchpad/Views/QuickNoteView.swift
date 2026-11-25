import SwiftUI

/// Quick note widget: click to write, Done / Esc / clicking elsewhere to finish. Saved as he types.
struct QuickNoteView: View {
    let inputs: WidgetInputs
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("QUICK NOTE").font(.system(size: 10, weight: .medium)).tracking(0.6)
                    .foregroundStyle(Color(white: 0.55))
                Spacer()
                if inputs.editingNote {
                    Button("Done") { inputs.actions.endNote() }.buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                } else if !inputs.quickNote.isEmpty {
                    Button("Clear") { inputs.actions.setQuickNote("") }.buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.6))
                        .help("Delete the note")
                }
            }
            if inputs.editingNote {
                TextEditor(text: Binding(get: { inputs.quickNote }, set: { inputs.actions.setQuickNote($0) }))
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.12)))
                    .focused($focused)
                    .onExitCommand { inputs.actions.endNote() }
                    .onAppear { DispatchQueue.main.async { focused = true } }
                    .environment(\.colorScheme, .dark)
            } else {
                Text(inputs.quickNote.isEmpty ? "Click to write a note" : inputs.quickNote)
                    .font(.system(size: 12))
                    .foregroundStyle(inputs.quickNote.isEmpty ? Color(white: 0.5) : .white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onTapGesture { inputs.actions.beginNote() }
                    .help("Click to edit")
            }
        }
    }
}
