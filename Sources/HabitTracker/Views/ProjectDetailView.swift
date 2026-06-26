import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var taskEditor: TaskEditorViewModel?
    @State private var milestoneEditor: MilestoneEditorViewModel?
    @State private var projectEditor: ProjectEditorViewModel?
    @State private var view: ViewMode = .list

    enum ViewMode: String, CaseIterable, Identifiable {
        case list = "List"
        case kanban = "Kanban"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("View", selection: $view) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            switch view {
            case .list: listView
            case .kanban: kanbanView
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New task", systemImage: "plus") {
                        taskEditor = TaskEditorViewModel(mode: .create(project: project), repository: repository())
                    }
                    Button("New milestone", systemImage: "flag") {
                        milestoneEditor = MilestoneEditorViewModel(mode: .create(project: project), container: modelContext.container)
                    }
                    Button("Edit project", systemImage: "pencil") {
                        projectEditor = ProjectEditorViewModel(mode: .edit(project: project), repository: repository())
                    }
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $taskEditor) { vm in TaskEditorSheet(viewModel: vm) }
        .sheet(item: $milestoneEditor) { vm in MilestoneEditorSheet(viewModel: vm) }
        .sheet(item: $projectEditor) { vm in ProjectEditorSheet(viewModel: vm) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !project.details.isEmpty {
                Text(project.details).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("\(project.completedTasks)/\(project.totalTasks) tasks · \(project.completedMilestones)/\(project.totalMilestones) milestones")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(project.progress * 100))%")
                    .font(.caption.monospacedDigit())
            }
            ProgressView(value: project.progress)
                .tint(project.progress >= 1 ? .green : .accentColor)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: List view

    private var listView: some View {
        List {
            if project.activeTasks.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "checklist",
                        description: Text("Add a task to start tracking work.")
                    )
                }
            } else {
                Section("Tasks") {
                    ForEach(project.activeTasks.sorted(by: { $0.order < $1.order })) { task in
                        taskRow(task)
                    }
                }
            }
            if !project.activeMilestones.isEmpty {
                Section("Milestones") {
                    ForEach(project.activeMilestones.sorted(by: { $0.order < $1.order })) { m in
                        milestoneRow(m)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: ProjectTask) -> some View {
        Button {
            taskEditor = TaskEditorViewModel(mode: .edit(task: task), repository: repository())
        } label: {
            HStack(spacing: 12) {
                Button {
                    cycleStatus(task)
                } label: {
                    Image(systemName: statusIcon(task.status))
                        .foregroundStyle(statusColor(task.status))
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .strikethrough(task.status == .done)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text("\(task.estimatedMinutes) min")
                            .font(.caption2).foregroundStyle(.secondary)
                        if let due = task.dueDate {
                            Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                Task { try? await repository().delete(task) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func milestoneRow(_ m: Milestone) -> some View {
        Button {
            milestoneEditor = MilestoneEditorViewModel(mode: .edit(milestone: m), container: modelContext.container)
        } label: {
            HStack {
                Image(systemName: m.isCompleted ? "checkmark.circle.fill" : "flag")
                    .foregroundStyle(m.isCompleted ? .green : .orange)
                Text(m.title).strikethrough(m.isCompleted)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                let now = Date.now
                m.deletedAt = now
                m.updatedAt = now
                try? modelContext.save()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: Kanban view

    private var kanbanView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    kanbanColumn(status: status)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func kanbanColumn(status: TaskStatus) -> some View {
        let tasks = project.tasks(in: status)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(statusColor(status)).frame(width: 8, height: 8)
                Text(status.label).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(tasks.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ForEach(tasks) { task in
                Button {
                    taskEditor = TaskEditorViewModel(mode: .edit(task: task), repository: repository())
                } label: {
                    kanbanCard(task)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    ForEach(TaskStatus.allCases, id: \.self) { target in
                        if target != task.status {
                            Button("Move to \(target.label)") {
                                task.status = target
                                task.updatedAt = .now
                                try? modelContext.save()
                            }
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        Task { try? await repository().delete(task) }
                    }
                }
            }
            Button {
                let new = TaskEditorViewModel(mode: .create(project: project), repository: repository())
                new.status = status
                taskEditor = new
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.systemBackground).opacity(0.6))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 260, alignment: .top)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func kanbanCard(_ task: ProjectTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title).font(.subheadline)
            HStack(spacing: 8) {
                Text("\(task.estimatedMinutes)m")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let due = task.dueDate {
                    Text(due.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: Helpers

    private func cycleStatus(_ task: ProjectTask) {
        switch task.status {
        case .todo: task.status = .doing
        case .doing: task.status = .done
        case .done: task.status = .todo
        }
        task.updatedAt = .now
        try? modelContext.save()
        Haptics.tap()
    }

    private func statusIcon(_ s: TaskStatus) -> String {
        switch s {
        case .todo: "circle"
        case .doing: "circle.dotted"
        case .done: "checkmark.circle.fill"
        }
    }

    private func statusColor(_ s: TaskStatus) -> Color {
        switch s {
        case .todo: .secondary
        case .doing: .blue
        case .done: .green
        }
    }

    private func repository() -> SwiftDataRepository {
        SwiftDataRepository(container: modelContext.container)
    }
}

// MARK: - Identifiable conformance for sheet bindings on @Observable VMs

extension HabitEditorViewModel: @MainActor Identifiable { var id: ObjectIdentifier { ObjectIdentifier(self) } }
extension MilestoneEditorViewModel: Identifiable { var id: ObjectIdentifier { ObjectIdentifier(self) } }
extension ProjectEditorViewModel: Identifiable { var id: ObjectIdentifier { ObjectIdentifier(self) } }
extension ObjectiveEditorViewModel: Identifiable { var id: ObjectIdentifier { ObjectIdentifier(self) } }
extension KeyResultEditorViewModel: Identifiable { var id: ObjectIdentifier { ObjectIdentifier(self) } }
extension TaskEditorViewModel: Identifiable { var id: ObjectIdentifier { ObjectIdentifier(self) } }
extension IngestionViewModel: Identifiable { var id: ObjectIdentifier { ObjectIdentifier(self) } }
