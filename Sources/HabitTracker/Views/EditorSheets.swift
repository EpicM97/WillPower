import SwiftUI

struct ObjectiveEditorSheet: View {
    @Bindable var viewModel: ObjectiveEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Objective") {
                    TextField("e.g. Ship v1, Reach $10K MRR", text: $viewModel.title)
                    TextField("Details (optional)", text: $viewModel.details, axis: .vertical)
                        .lineLimit(2...5)
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

struct ProjectEditorSheet: View {
    @Bindable var viewModel: ProjectEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("e.g. MVP polish, Q3 roadmap", text: $viewModel.title)
                    TextField("Details (optional)", text: $viewModel.details, axis: .vertical)
                        .lineLimit(2...5)
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

struct MilestoneEditorSheet: View {
    @Bindable var viewModel: MilestoneEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Milestone") {
                    TextField("e.g. First user signed up", text: $viewModel.title)
                }
                Section {
                    Toggle("Completed", isOn: $viewModel.isCompleted)
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

/// Shared toolbar with Cancel + Save for any editor sheet.
@ToolbarContentBuilder
func editorToolbar(
    isValid: Bool,
    saving: Bool,
    confirm: @escaping () async -> Void,
    cancel: @escaping () -> Void
) -> some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
        Button("Cancel", action: cancel)
    }
    ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
            Task { await confirm() }
        }
        .disabled(!isValid || saving)
    }
}
