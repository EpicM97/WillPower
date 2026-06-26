# CLAUDE.md - Project Guidelines

## Build & Test Commands
- **Build Project**: `xcodebuild -scheme HabitTracker -destination 'platform=iOS Simulator,name=iPhone 17' build`
- **Run Tests**: `xcodebuild test -scheme HabitTracker -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Clean Build**: `xcodebuild clean -scheme HabitTracker`
- **SwiftLint (Optional)**: `swiftlint`

## Tech Stack
- **UI**: SwiftUI (Life Activities & Dynamic Island focus)
- **Local Persistence**: SwiftData (Model-driven)
- **Remote Backend**: Supabase (PostgreSQL, Auth, Edge Functions)
- **Architecture**: Repository Pattern (Decouple Supabase from UI)
- **Concurrency**: Swift Structured Concurrency (Async/Await)

## Coding Standards
1. **Harness First**: Always check or create a unit test in `Tests/` before implementing new logic.
2. **Naming**: PascalCase for Types/Protocols, camelCase for variables/functions. Use descriptive names (e.g., `calculateRemainingBudget` instead of `calcTime`).
3. **SwiftUI**: Use `@Observable` for ViewModels. Keep Views small; decompose into sub-views if >100 lines.
4. **Data Flow**: Use `Repository` protocols to allow mocking Supabase in tests.
5. **Errors**: Use custom `Error` enums. No silent failures (handle all `do-catch` blocks).
6. **Async**: Prefer `async/await` over completion closures.

## Documentation (SDLC layout)
- **`implementation-plan.md`** — engineering **changelog** (history; keep appending per the rule below).
- **`docs/product/backlog.md`** — forward work (now / next / later / open QA / ops).
- **`docs/product/test-plan.md`** — manual QA test pass.
- **`docs/architecture/tech-spec.md`** — current-state system design; **keep accurate** when systems change.
- **`docs/architecture/decisions.md`** — ADRs; add one per hard, hard-to-reverse decision.
- **`docs/architecture/overview.md`**, **`docs/specs/*`**, **`docs/SUPABASE_SETUP.md`** — layers, algorithm specs, backend runbook.
- Index: [`docs/README.md`](docs/README.md).

## AI Agent Rules (Claude Code)
- **Context Management**: Do NOT scan `DerivedData/` or `.swiftpm/`.
- **State Update**: After every successful task, update `implementation-plan.md` (changelog) with progress and "Known Issues"; also update `docs/product/backlog.md` and `docs/architecture/tech-spec.md` when scope or design shifts.
- **Refactoring**: If you see a way to reduce code complexity by >20%, propose it before implementation.
- **Safety**: Do not modify `Entitlements` or `Info.plist` without explicit confirmation.
- **Supabase ops**: Use the `Makefile` targets (`make db-push`, `make functions-deploy FN=...`, etc.) instead of raw `supabase` invocations. The CLI is installed; do NOT run `supabase login` / `supabase link` yourself — those are user-interactive one-time setup. See `docs/SUPABASE_SETUP.md`.
