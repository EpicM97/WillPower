import SwiftUI

struct HabitEditorSheet: View {
    @Bindable var viewModel: HabitEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("e.g. Sprint, Email, Read", text: $viewModel.title)
                        .textInputAutocapitalization(.sentences)
                }
                Section {
                    Picker("Kind", selection: $viewModel.kind) {
                        Text("Duration").tag(HabitKind.duration)
                        Text("Moment").tag(HabitKind.moment)
                        Text("Anchored").tag(HabitKind.anchored)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.kind) { _, newKind in
                        if newKind != .moment && viewModel.estimatedMinutes == 0 {
                            viewModel.estimatedMinutes = 30
                        }
                    }
                } header: {
                    Text("Kind")
                } footer: {
                    Text(kindFooter)
                }
                Section("Energy") {
                    Picker("Energy level", selection: $viewModel.energy) {
                        Text("High").tag(EnergyLevel.high)
                        Text("Mid").tag(EnergyLevel.mid)
                        Text("Low").tag(EnergyLevel.low)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Picker("Priority", selection: $viewModel.priority) {
                        Text("Low").tag(0)
                        Text("Normal").tag(1)
                        Text("High").tag(2)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Priority")
                } footer: {
                    Text("Lower-priority habits get compressed first when the day is tight.")
                }
                if viewModel.kind == .anchored {
                    Section {
                        DatePicker("At", selection: anchorTimeBinding, displayedComponents: .hourAndMinute)
                    } header: {
                        Text("Time")
                    } footer: {
                        Text("The clock time this block is pinned to.")
                    }
                }
                if viewModel.kind != .moment {
                    Section {
                        HStack {
                            Text(viewModel.kind == .anchored ? "Block length" : "Estimated")
                            Spacer()
                            MinutesField(value: $viewModel.estimatedMinutes)
                        }
                    } header: {
                        Text("Duration")
                    } footer: {
                        Text("Tap the number to type any value; −/+ step by 1.")
                    }
                }
                if let error = viewModel.lastError {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() { dismiss() }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.saving)
                }
            }
        }
    }

    /// Bridges the view-model's minutes-from-midnight anchor to a `Date` the
    /// system time picker can edit (today's date at that clock time).
    private var anchorTimeBinding: Binding<Date> {
        Binding(
            get: {
                let cal = Calendar.current
                return cal.date(bySettingHour: viewModel.anchorMinuteOfDay / 60,
                                minute: viewModel.anchorMinuteOfDay % 60,
                                second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                viewModel.anchorMinuteOfDay = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private var kindFooter: String {
        switch viewModel.kind {
        case .duration: "Takes real time and flexes when your day is tight."
        case .moment: "A quick check-in (e.g. drink water) — no time budget."
        case .anchored: "A fixed block at a set time (e.g. wake-up, work) — reserved, never compressed."
        }
    }
}
