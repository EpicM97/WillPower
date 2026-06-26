import SwiftData
import SwiftUI

/// Pushed via the gear icon on ProfileView. Hosts everything that isn't
/// identity: sync controls, app info, account actions.
struct SettingsView: View {
    @Bindable var coordinator: AuthCoordinator
    @Environment(\.modelContext) private var modelContext
    @State private var syncStatus: String?
    @State private var syncing = false
    @State private var signingOut = false

    var body: some View {
        Form {
            syncSection
            #if DEBUG
            // Demo/debug controls are developer tooling — never shipped to users.
            // Rollover + sync run automatically (see HabitTrackerApp.onForeground).
            dataSection
            #endif
            aboutSection
            signOutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var syncSection: some View {
        Section("Sync") {
            Button {
                Task { await runSync() }
            } label: {
                HStack {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if syncing { ProgressView() }
                }
            }
            .disabled(syncing)

            if let syncStatus {
                Text(syncStatus).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                DemoSeeder.forceSeed(container: modelContext.container)
            } label: {
                Label("Re-seed demo data", systemImage: "sparkles")
            }
            Button(role: .destructive) {
                DemoSeeder.resetToHabitsOnly(container: modelContext.container)
                Haptics.success()
            } label: {
                Label("Reset to habits only (0/120)", systemImage: "trash.slash")
            }
            Button {
                JournalArchiver.rollover(in: modelContext.container.mainContext)
                Haptics.success()
            } label: {
                Label("Run end-of-day rollover now", systemImage: "moon.stars")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                Task {
                    signingOut = true
                    await coordinator.signOut()
                    signingOut = false
                }
            } label: {
                HStack {
                    Text("Sign out")
                    Spacer()
                    if signingOut { ProgressView() }
                }
            }
            .disabled(signingOut)
        }
    }

    private func runSync() async {
        syncing = true
        defer { syncing = false }
        guard let config = try? SupabaseConfig.fromBundle() else {
            syncStatus = "Set SUPABASE_URL / SUPABASE_ANON_KEY in Supabase.xcconfig."
            return
        }
        let service = SupabaseSyncService(config: config)
        let coord = SyncCoordinator(container: modelContext.container, service: service)
        do {
            let stats = try await coord.syncNow()
            syncStatus = "Pulled \(stats.pulled), pushed \(stats.pushed)."
        } catch {
            syncStatus = "Failed: \(error)"
        }
    }
}
