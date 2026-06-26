import SwiftUI

struct TaskEditorSheet: View {
    @Bindable var viewModel: TaskEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("e.g. Wire up onboarding analytics", text: $viewModel.title)
                    TextField("Notes (optional)", text: $viewModel.details, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Status") {
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(TaskStatus.allCases, id: \.self) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Estimate") {
                    Stepper(value: $viewModel.estimatedMinutes, in: 5...480, step: 5) {
                        HStack {
                            Text("Minutes")
                            Spacer()
                            Text("\(viewModel.estimatedMinutes)").foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Toggle("Has due date", isOn: Binding(
                        get: { viewModel.dueDate != nil },
                        set: { viewModel.dueDate = $0 ? (viewModel.dueDate ?? .now) : nil }
                    ))
                    if let due = viewModel.dueDate {
                        DatePicker("Due", selection: Binding(
                            get: { due },
                            set: { viewModel.dueDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                if let err = viewModel.lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar(isValid: viewModel.isValid, saving: viewModel.saving) {
                if await viewModel.save() { dismiss() }
            } cancel: { dismiss() } }
        }
    }
}
