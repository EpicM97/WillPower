import SwiftData
import SwiftUI

/// The reflection recap surface: "On this day" memories from prior years plus a
/// reverse-chronological list of recent reflections. Notes are decrypted on the
/// fly with the device key — they live encrypted at rest.
struct MemoriesView: View {
    @Query(sort: \Journal.date, order: .reverse) private var journals: [Journal]
    private let key = JournalKeyStore().key()

    var body: some View {
        List {
            let onThisDay = OnThisDaySelector.onThisDay(reference: .now, journals: journals)
            if !onThisDay.isEmpty {
                Section("On this day") {
                    ForEach(onThisDay) { entry in row(entry) }
                }
            }

            let recent = journals.filter { $0.deletedAt == nil && hasNote($0) }
            if recent.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No memories yet",
                        systemImage: "book.closed",
                        description: Text("Your evening reflections show up here — wins and hard days alike.")
                    )
                }
            } else {
                Section("Recent reflections") {
                    ForEach(recent) { entry in row(entry) }
                }
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hasNote(_ journal: Journal) -> Bool {
        decrypted(journal)?.isEmpty == false
    }

    private func decrypted(_ journal: Journal) -> String? {
        JournalCrypto.open(journal.summaryNote, key: key)
    }

    @ViewBuilder private func row(_ journal: Journal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(journal.date, format: .dateTime.weekday(.wide).month().day().year())
                .font(.caption).foregroundStyle(.secondary)
            if let note = decrypted(journal), !note.isEmpty {
                Text(note).font(.subheadline)
            } else if JournalCrypto.isSealed(journal.summaryNote) {
                Label("Locked — written on another device", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No note").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
