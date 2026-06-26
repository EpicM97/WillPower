import SwiftData
import SwiftUI

/// Work tab root: lists Objectives, each with its KRs and Projects nested.
struct ProjectDashboardView: View {
    @Bindable var viewModel: ProjectDashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var objectiveEditor: ObjectiveEditorViewModel?
    @State private var krEditor: KeyResultEditorViewModel?
    @State private var projectEditor: ProjectEditorViewModel?

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.objectives.isEmpty {
                    Section("Overall") { overallRow }
                }
                if viewModel.objectives.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Set an objective", systemImage: "scope")
                        } description: {
                            Text("Objectives hold key results. Each key result has projects with tasks and milestones.")
                        } actions: {
                            Button("Add your first objective") {
                                objectiveEditor = ObjectiveEditorViewModel(mode: .create, repository: repository())
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.objectives) { objective in
                        objectiveSection(objective)
                    }
                }
            }
            .navigationTitle("Work")
            .toolbar {
                if !viewModel.objectives.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            objectiveEditor = ObjectiveEditorViewModel(mode: .create, repository: repository())
                        } label: { Image(systemName: "plus") }
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(item: $objectiveEditor, onDismiss: { Task { await viewModel.load() } }) { vm in
                ObjectiveEditorSheet(viewModel: vm)
            }
            .sheet(item: $krEditor, onDismiss: { Task { await viewModel.load() } }) { vm in
                KeyResultEditorSheet(viewModel: vm)
            }
            .sheet(item: $projectEditor, onDismiss: { Task { await viewModel.load() } }) { vm in
                ProjectEditorSheet(viewModel: vm)
            }
        }
    }

    @ViewBuilder
    private func objectiveSection(_ objective: Objective) -> some View {
        Section {
            if objective.activeKeyResults.isEmpty {
                Button {
                    krEditor = KeyResultEditorViewModel(mode: .create(objective: objective), repository: repository())
                } label: {
                    Label("Add key result", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
            } else {
                ForEach(objective.activeKeyResults) { kr in
                    krRow(kr)
                }
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(objective.title).font(.headline)
                    if let due = objective.dueDate {
                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Button("Add key result", systemImage: "plus") {
                        krEditor = KeyResultEditorViewModel(mode: .create(objective: objective), repository: repository())
                    }
                    Button("Edit objective", systemImage: "pencil") {
                        objectiveEditor = ObjectiveEditorViewModel(mode: .edit(objective: objective), repository: repository())
                    }
                    Button("Delete objective", systemImage: "trash", role: .destructive) {
                        Task { await viewModel.delete(objective: objective) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.tint)
                }
            }
            .textCase(nil)
        }
    }

    @ViewBuilder
    private func krRow(_ kr: KeyResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kr.title).font(.subheadline.weight(.medium))
                Spacer()
                if kr.targetValue > 0 {
                    Text("\(Int(kr.currentValue))/\(Int(kr.targetValue)) \(kr.metricUnit)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if kr.targetValue > 0 {
                ProgressView(value: kr.progress)
            }
            if kr.activeProjects.isEmpty {
                Button {
                    projectEditor = ProjectEditorViewModel(mode: .create(keyResult: kr), repository: repository())
                } label: {
                    Label("Add project", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(kr.activeProjects) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        ProjectRowView(project: project)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(project: project) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button {
                    projectEditor = ProjectEditorViewModel(mode: .create(keyResult: kr), repository: repository())
                } label: {
                    Label("Add project", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button(role: .destructive) {
                Task { await viewModel.delete(keyResult: kr) }
            } label: { Label("Delete KR", systemImage: "trash") }
        }
    }

    private var overallRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(viewModel.totalProjects) project\(viewModel.totalProjects == 1 ? "" : "s") · \(viewModel.totalKeyResults) KR")
                    .font(.headline)
                Spacer()
                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: viewModel.overallProgress)
        }
        .padding(.vertical, 4)
    }

    private func repository() -> SwiftDataRepository {
        SwiftDataRepository(container: modelContext.container)
    }
}
