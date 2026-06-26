import SwiftUI
import SwiftData

@main
struct HabitTrackerApp: App {
    let container: ModelContainer = {
        do {
            return try AppSchema.sharedContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var coordinator: AuthCoordinator = AuthCoordinator(auth: Self.makeAuthService())
    @State private var preferences = ProfilePreferences.shared
    @State private var didOnboard: Bool = UserDefaults.standard.bool(forKey: OnboardingView.doneKey)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if !didOnboard {
                    OnboardingView { didOnboard = true }
                } else {
                    switch coordinator.state {
                    case .checking:
                        SplashView()
                    case .signedOut:
                        AuthRootView(coordinator: coordinator)
                    case .signedIn:
                        RootView(coordinator: coordinator)
                    }
                }
            }
            .preferredColorScheme(preferences.appearance.colorScheme)
            .environment(preferences)
            .task {
                DemoSeeder.seedIfNeeded(container: container)
                MidnightRollover.scheduleNext()
                await coordinator.bootstrap()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await onForeground() } }
            }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(MidnightRollover.identifier)) {
            await MainActor.run { MidnightRollover.handle(container: container) }
        }
    }

    /// On every foreground: catch up the end-of-day rollover (idempotent — only
    /// archives past completed days) and kick an automatic cloud sync. Only when
    /// signed in. Replaces the manual Settings buttons for normal use.
    @MainActor
    private func onForeground() async {
        guard case .signedIn = coordinator.state else { return }
        JournalArchiver.rollover(in: container.mainContext)
        await AutoSync.run(container: container)
    }

    private static func makeAuthService() -> any AuthService {
        if let config = try? SupabaseConfig.fromBundle() {
            return SupabaseAuthService(config: config)
        }
        return MockAuthService()
    }
}

private struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            ProgressView()
        }
    }
}
