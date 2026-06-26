import SwiftUI
import SwiftData

struct RootView: View {
    @Bindable var coordinator: AuthCoordinator
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .today
    @State private var focusedHabitID: UUID?
    @State private var reportsViewModel: ReportsViewModel = ReportsViewModel(service: Self.makeReportsService())

    enum Tab: Hashable { case today, projects, reports, profile }

    var body: some View {
        TabView(selection: $selectedTab) {
            DailyDeckView(
                viewModel: makeDeckViewModel(),
                focusedHabitID: $focusedHabitID
            )
                .tabItem { Label("Today", systemImage: "rectangle.stack") }
                .tag(Tab.today)

            ProjectDashboardView(viewModel: makeDashboardViewModel())
                .tabItem { Label("Projects", systemImage: "target") }
                .tag(Tab.projects)

            ReportsView(viewModel: reportsViewModel)
                .tabItem { Label("Reports", systemImage: "chart.bar") }
                .tag(Tab.reports)

            ProfileView(coordinator: coordinator)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .onOpenURL { url in
            guard let link = DeepLink.from(url) else { return }
            switch link {
            case .habit(let id):
                selectedTab = .today
                focusedHabitID = id
            }
        }
    }

    private func repository() -> SwiftDataRepository {
        SwiftDataRepository(container: modelContext.container)
    }

    private func makeDeckViewModel() -> DailyDeckViewModel {
        DailyDeckViewModel(repository: repository())
    }

    private func makeDashboardViewModel() -> ProjectDashboardViewModel {
        ProjectDashboardViewModel(repository: repository())
    }

    private static func makeReportsService() -> any ReportsService {
        if let config = try? SupabaseConfig.fromBundle() {
            return SupabaseReportsService(config: config)
        }
        return MockReportsService()
    }
}
