import SwiftUI

struct KeyResultEditorSheet: View {
    @Bindable var viewModel: KeyResultEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Key result") {
                    TextField("e.g. Reach 100 paying users", text: $viewModel.title)
                }
                Section("Metric (optional)") {
                    HStack {
                        TextField("Unit", text: $viewModel.metricUnit)
                        Spacer()
                    }
                    Stepper(value: $viewModel.targetValue, in: 0...100000, step: 1) {
                        HStack {
                            Text("Target")
                            Spacer()
                            Text("\(Int(viewModel.targetValue))").foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $viewModel.currentValue, in: 0...100000, step: 1) {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text("\(Int(viewModel.currentValue))").foregroundStyle(.secondary)
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
