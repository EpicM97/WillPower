import Foundation
import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Objective.self,
        KeyResult.self,
        Project.self,
        Milestone.self,
        ProjectTask.self,
        Habit.self,
        DailySession.self,
        HabitEntry.self,
        Journal.self
    ]

    static func inMemoryContainer() throws -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Container backed by the App Group store so the main app and the widget
    /// extension can read/write the same data. Falls back to the default
    /// (per-app sandbox) URL when the App Group isn't available (e.g. previews).
    static func sharedContainer() throws -> ModelContainer {
        let schema = Schema(models)
        let config: ModelConfiguration
        if let url = AppGroup.sharedStoreURL {
            config = ModelConfiguration(schema: schema, url: url)
        } else {
            config = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
