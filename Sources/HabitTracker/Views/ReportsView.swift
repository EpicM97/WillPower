import SwiftUI

struct ReportsView: View {
    @Bindable var viewModel: ReportsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: Binding(
                        get: { viewModel.range },
                        set: { newRange in Task { await viewModel.switchRange(newRange) } }
                    )) {
                        ForEach(ReportRange.allCases, id: \.self) { r in
                            Text(r.rawValue.capitalized).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let report = viewModel.report {
                    summarySection(report)
                    topHabitsSection(report)
                    byDaySection(report)
                } else if let error = viewModel.lastError {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
            .navigationTitle("Reports")
            .task { await viewModel.load() }
        }
    }

    private func summarySection(_ r: ProgressReport) -> some View {
        Section("Summary") {
            row("Total time", value: "\(r.totalMinutes) min")
            row("Sessions", value: "\(r.sessionCount)")
            row("Milestones", value: "\(r.milestonesCompleted)")
            if let accuracy = r.estimationAccuracy {
                row("Estimation accuracy", value: "\(Int(accuracy * 100))%")
            }
        }
    }

    private func topHabitsSection(_ r: ProgressReport) -> some View {
        Section("Top habits") {
            if r.topHabits.isEmpty {
                Text("Nothing logged this \(r.range.rawValue).").foregroundStyle(.secondary)
            } else {
                ForEach(r.topHabits) { h in
                    HStack {
                        Text(h.title)
                        Spacer()
                        Text("\(h.minutes) min").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func byDaySection(_ r: ProgressReport) -> some View {
        Section("By day") {
            if r.byDay.isEmpty {
                Text("No activity yet.").foregroundStyle(.secondary)
            } else {
                ForEach(r.byDay) { d in
                    HStack {
                        Text(d.date)
                        Spacer()
                        Text("\(d.minutes) min · \(d.sessions)x").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
}
