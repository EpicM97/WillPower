import SwiftUI

struct InterruptionInjectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onInject: (String, EnergyLevel, Int) async -> Void

    @State private var title: String = ""
    @State private var energy: EnergyLevel = .mid
    @State private var minutes: Int = MinutesInput.fallback
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What just happened?") {
                    TextField("e.g. Phone call, ad-hoc meeting", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Energy") {
                    Picker("Energy level", selection: $energy) {
                        Text("High").tag(EnergyLevel.high)
                        Text("Mid").tag(EnergyLevel.mid)
                        Text("Low").tag(EnergyLevel.low)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    HStack {
                        Text("Estimated")
                        Spacer()
                        MinutesField(value: $minutes)
                    }
                } header: {
                    Text("How long will it take?")
                } footer: {
                    Text("Tap the number to type any value; −/+ step by 1.")
                }
                Section {
                    Text("Your remaining habits will compress to fit. Discipline isn't punished — completing the smaller versions still counts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Inject interruption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Inject") {
                        Task {
                            saving = true
                            await onInject(title, energy, minutes)
                            saving = false
                            dismiss()
                        }
                    }
                    .disabled(saving)
                }
            }
        }
    }
}
