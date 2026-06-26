import SwiftUI

struct IngestionSheet: View {
    @Bindable var viewModel: IngestionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var dictator = VoiceDictator()

    var body: some View {
        NavigationStack {
            Group {
                if let result = viewModel.applyResult {
                    successView(result)
                } else if viewModel.proposal != nil {
                    proposalView
                } else {
                    inputView
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dictator.stop()
                        dismiss()
                    }
                }
                if viewModel.proposal != nil && viewModel.applyResult == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            viewModel.applyAccepted()
                            Haptics.success()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var navTitle: String {
        if viewModel.applyResult != nil { return "Added" }
        if viewModel.proposal != nil { return "Review" }
        return "Brain dump"
    }

    // MARK: Input

    private var inputView: some View {
        Form {
            Section {
                TextField("Dump anything — habits, milestones, ad-hoc tasks…", text: $viewModel.rawText, axis: .vertical)
                    .lineLimit(6...12)
                    .textInputAutocapitalization(.sentences)
                    .onChange(of: dictator.liveTranscript) { _, new in
                        if !new.isEmpty { viewModel.rawText = new }
                    }
            } footer: {
                Text("We'll parse it into habits, milestones, and interruptions. You confirm before anything is created.")
            }
            Section {
                dictateRow
                Button {
                    Task { await viewModel.parse() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.loading { ProgressView() }
                        else { Text("Parse with AI").fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.loading || viewModel.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let err = viewModel.lastError {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }
        }
    }

    private var dictateRow: some View {
        let isRecording: Bool = {
            if case .recording = dictator.state { return true } else { return false }
        }()
        return Button {
            if isRecording { dictator.stop() }
            else { Task { await dictator.start() } }
        } label: {
            HStack {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                    .foregroundStyle(isRecording ? .red : .accentColor)
                Text(isRecording ? "Stop dictating" : "Dictate by voice")
                Spacer()
                if case .denied(let msg) = dictator.state {
                    Text(msg).font(.caption2).foregroundStyle(.red).lineLimit(1)
                } else if case .error(let msg) = dictator.state {
                    Text(msg).font(.caption2).foregroundStyle(.red).lineLimit(1)
                } else if case .authorizing = dictator.state {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    // MARK: Proposal review

    private var proposalView: some View {
        Form {
            if let note = viewModel.proposal?.modelNote {
                Section { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
            if let p = viewModel.proposal {
                if !p.habits.isEmpty {
                    Section("Habits") {
                        ForEach(p.habits) { h in
                            row(
                                title: h.title,
                                subtitle: "\(h.estimatedMinutes) min · \(h.energy.rawValue) energy" + (h.projectHint.map { " · \($0)" } ?? ""),
                                isOn: viewModel.accept.habits.contains(h.id)
                            ) { viewModel.toggleHabit(h.id) }
                        }
                    }
                }
                if !p.milestones.isEmpty {
                    Section("Milestones") {
                        ForEach(p.milestones) { m in
                            row(
                                title: m.title,
                                subtitle: m.projectHint ?? "no project hint",
                                isOn: viewModel.accept.milestones.contains(m.id)
                            ) { viewModel.toggleMilestone(m.id) }
                        }
                    }
                }
                if !p.interruptions.isEmpty {
                    Section("Today's interruptions") {
                        ForEach(p.interruptions) { it in
                            row(
                                title: it.title,
                                subtitle: "\(it.expectedMinutes) min",
                                isOn: viewModel.accept.interruptions.contains(it.id)
                            ) { viewModel.toggleInterruption(it.id) }
                        }
                    }
                }
            }
        }
    }

    private func row(title: String, subtitle: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? .green : .secondary)
                VStack(alignment: .leading) {
                    Text(title).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Success

    private func successView(_ r: IngestApplier.ApplyResult) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Added to your plan")
                .font(.title3.bold())
            VStack(spacing: 4) {
                if r.habitsCreated > 0 { Text("\(r.habitsCreated) habit\(r.habitsCreated == 1 ? "" : "s")") }
                if r.milestonesCreated > 0 { Text("\(r.milestonesCreated) milestone\(r.milestonesCreated == 1 ? "" : "s")") }
                if r.interruptionsCreated > 0 { Text("\(r.interruptionsCreated) interruption\(r.interruptionsCreated == 1 ? "" : "s") today") }
            }
            .foregroundStyle(.secondary)
            if !r.skipped.isEmpty {
                Text("Skipped: \(r.skipped.joined(separator: "; "))")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding()
    }
}
