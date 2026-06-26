import SwiftData
import SwiftUI

/// Adaptive Today layout shown after 8 PM. Replaces the deck with a reflection
/// surface: discipline ring, breakdown counts, optional note for the journal.
struct EveningRitualView: View {
    @Bindable var viewModel: DailyDeckViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var note: String = ""
    @State private var saving = false
    @State private var savedFlash = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                breakdown
                noteCard
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .task { loadExistingNote() }
    }

    /// Pre-fill the field with today's already-saved reflection, decrypted, so
    /// re-opening the prompt shows what was written rather than a blank box.
    private func loadExistingNote() {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<Journal>(predicate: #Predicate { $0.date == start })
        guard let existing = try? modelContext.fetch(descriptor).first,
              let decrypted = JournalCrypto.open(existing.summaryNote, key: JournalKeyStore().key()) else { return }
        note = decrypted
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Text("Evening ritual")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            LabelledProgressRing(
                progress: viewModel.todayDisciplineScore ?? 0,
                label: "discipline today"
            )
            .frame(maxWidth: .infinity)
            Text(headlineCopy)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Text("Tomorrow is a blank canvas.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var breakdown: some View {
        HStack(spacing: 12) {
            stat(label: "Completed", value: viewModel.completedSessions.count, tint: .green)
            stat(label: "Interruptions", value: viewModel.sessions.filter { $0.isInterruption }.count, tint: .orange)
        }
    }

    private func stat(label: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title2.bold()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anything worth remembering?")
                .font(.headline)
            TextField("Optional note for today", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            Label("Encrypted on this device — only you can read it.", systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                if savedFlash {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                Button {
                    Task { await saveNote() }
                } label: {
                    if saving { ProgressView() } else { Text("Save reflection") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var headlineCopy: String {
        guard let score = viewModel.todayDisciplineScore else { return "Nothing logged yet today." }
        switch score {
        case 0.9...: return "Crushing it. Rest well."
        case 0.6..<0.9: return "Solid day. Streak intact."
        case 0.3..<0.6: return "Showed up. That counts."
        default: return "Reset. Tomorrow is fresh."
        }
    }

    private func saveNote() async {
        saving = true
        defer { saving = false }
        let context = modelContext
        let journal = JournalArchiver.archive(in: context)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let journal, !trimmed.isEmpty {
            // Seal on-device before it ever touches the store or sync (E2EE).
            journal.summaryNote = JournalCrypto.seal(trimmed, key: JournalKeyStore().key())
            journal.updatedAt = .now
            try? context.save()
        }
        Haptics.success()
        withAnimation { savedFlash = true }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        withAnimation { savedFlash = false }
    }
}
