import SwiftUI

/// Lets the user define their active day (start / end / wind-down), their
/// discretionary habit budget, and opt into start + wind-down nudges. The
/// budget is intentionally a separate input from the window length — budget is
/// *not* waking hours.
struct DayBudgetSettingsView: View {
    @State private var window: DayWindow = DayWindowStore().current
    @State private var customWindDown: Bool = DayWindowStore().current.windDownMinuteOfDay != nil
    private let store = DayWindowStore()

    var body: some View {
        Form {
            Section {
                DatePicker("Day starts", selection: minuteBinding(\.startMinuteOfDay), displayedComponents: .hourAndMinute)
                DatePicker("Day ends", selection: minuteBinding(\.endMinuteOfDay), displayedComponents: .hourAndMinute)
            } header: {
                Text("Your day")
            } footer: {
                Text("When your day begins and ends. This drives nudges and anchored habits — not your budget.")
            }

            Section {
                HStack {
                    Text("Discretionary budget")
                    Spacer()
                    MinutesField(value: budgetBinding)
                }
            } header: {
                Text("Budget")
            } footer: {
                Text("Time you want to invest in habits today. Set it directly — it isn't your whole waking day.")
            }

            Section {
                Toggle("Custom wind-down time", isOn: $customWindDown)
                    .onChange(of: customWindDown) { _, on in
                        window.windDownMinuteOfDay = on ? window.resolvedWindDownMinute : nil
                        persist()
                    }
                if customWindDown {
                    DatePicker("Wind down at", selection: windDownBinding, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Wind-down")
            } footer: {
                Text(customWindDown ? "When your evening reflection prompt surfaces." : "Defaults to one hour before your day ends.")
            }

            Section {
                Toggle("Start & wind-down nudges", isOn: $window.notificationsEnabled)
                    .onChange(of: window.notificationsEnabled) { _, _ in persist() }
            } header: {
                Text("Notifications")
            } footer: {
                Text("At most two a day — a gentle start and a wind-down. Value, not nag.")
            }
        }
        .navigationTitle("Day & budget")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Bindings

    private func minuteBinding(_ keyPath: WritableKeyPath<DayWindow, Int>) -> Binding<Date> {
        Binding(
            get: { Self.date(fromMinute: window[keyPath: keyPath]) },
            set: { window[keyPath: keyPath] = Self.minute(from: $0); persist() }
        )
    }

    private var windDownBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinute: window.resolvedWindDownMinute) },
            set: { window.windDownMinuteOfDay = Self.minute(from: $0); persist() }
        )
    }

    private var budgetBinding: Binding<Int> {
        Binding(
            get: { window.budgetMinutes },
            set: { window.budgetMinutes = $0; persist() }
        )
    }

    private func persist() {
        store.save(window)
        let snapshot = window
        Task { await DayNotificationService().reschedule(for: snapshot) }
    }

    private static func date(fromMinute minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minute(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
