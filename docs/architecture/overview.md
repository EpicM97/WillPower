# Architecture Overview

> Replaces the old `docs/architecture.md`, which described the deleted
> `Goal`/`DailyLog` v1 models. For full system design see
> [tech-spec.md](tech-spec.md).

## Tech stack
- **UI** SwiftUI (Live Activities / Dynamic Island focus)
- **Local** SwiftData (offline-first, model-driven)
- **Cloud** Supabase — Postgres, Auth (email OTP), Edge Functions (Deno), Storage
- **Pattern** Repository (decouple Supabase from UI) · `@Observable` view-models · structured `async/await`

## Layers
| Layer | Folder | Notes |
|-------|--------|-------|
| App / wiring | `App/` | `HabitTrackerApp`, onboarding gate, scenePhase auto-sync, midnight rollover |
| Models | `Models/` | SwiftData `@Model`: `Habit`, `DailySession`, `Journal`, OKR graph |
| Shared | `Sources/Shared/` | Widget-shared: `HabitKind`, `EnergyLevel`, `DeepLink`, intents |
| Repositories | `Repositories/` | `DataRepository` protocol → `SwiftDataRepository` / `MockRepository` |
| Logic | `Logic/` | Pure, unit-tested: budget, day-window, evening policy, journal crypto, sorters |
| ViewModels | `ViewModels/` | `@Observable @MainActor` state holders |
| Views | `Views/`, `Profile/`, `Auth/`, `Settings/` | SwiftUI; decomposed when large |
| Cloud | `Supabase/` | DTOs, mapping, sync coordinator, services |

## Harness engineering
Every logic module ships with a matching XCTest in `Tests/HabitTrackerTests/`.
New logic is **test-first** (the failing test precedes the implementation).
Repository protocols are the seam for mocking Supabase.

## Build & test
```
make build      # xcodegen + xcodebuild build
make test       # xcodegen + xcodebuild test  (176 tests)
make db-push    # apply additive migrations to Supabase
```
See [../SUPABASE_SETUP.md](../SUPABASE_SETUP.md) for backend setup.
