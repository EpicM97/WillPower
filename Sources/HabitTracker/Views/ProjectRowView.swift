import SwiftUI

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            ProgressRing(
                progress: project.progress,
                tint: project.progress >= 1 ? .green : .accentColor,
                lineWidth: 5,
                size: 36
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title).font(.headline)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var detailLine: String {
        let tasks = project.totalTasks
        let mile = project.totalMilestones
        switch (tasks, mile) {
        case (0, 0): return "Empty — add tasks or milestones"
        case (_, 0): return "\(project.completedTasks)/\(tasks) tasks"
        case (0, _): return "\(project.completedMilestones)/\(mile) milestones"
        default: return "\(project.completedTasks)/\(tasks) tasks · \(project.completedMilestones)/\(mile) milestones"
        }
    }
}
