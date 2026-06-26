# Technical Specification — Current State

The engineering reference for how WillPower works today. Kept accurate (not a
changelog — that's [`implementation-plan.md`](../../implementation-plan.md)).

## 1. Stack & layers
- **UI**: SwiftUI. **Persistence**: SwiftData (offline-first). **Backend**: Supabase (Postgres + Auth + Edge Functions + Storage).
- **Architecture**: Repository pattern (`DataRepository` protocol → `SwiftDataRepository` / `MockRepository`). `@Observable @MainActor` view-models. Pure logic in `Sources/HabitTracker/Logic/` with matching XCTests (harness-first).
- **Concurrency**: structured `async/await`.

```
Sources/
  HabitTracker/{App, Models, Repositories, ViewModels, Views, Logic, Profile, Auth, Settings, Supabase, Onboarding}
  Shared/        (code shared with the widget: HabitKind, EnergyLevel, DeepLink, LogHabitIntent, …)
Tests/HabitTrackerTests/
supabase/{migrations, functions, storage}
```

## 2. Domain model
- **`Habit`** — `title`, `energy`, `estimatedMinutes`, `order`, `priority`, **`kind: HabitKind`**, **`anchorMinuteOfDay: Int?`**, `updatedAt`, `deletedAt?`.
- **`HabitKind`** (`Sources/Shared`) — `.duration` (flexes), `.moment` (≈0 budget), `.anchored` (fixed block at a clock time).
- **`DailySession`** — a materialized run of a habit for a day: `baseMinutes` / `compressedMinutes` / `actualMinutes?` / `status` (pending·active·completed·deferred) / `isInterruption` / `energy` / `stoppedEarly` / `orderHint` / `note`. `kind` derives from its habit.
- **`Journal`** — end-of-day snapshot: discipline score + counts + `summaryNote` (**E2EE**, see §6).
- **OKR graph** (local-only): `Objective → KeyResult → Project → {Milestone, ProjectTask}`. Not synced.

Only **Habits, Sessions, Journals** sync remotely (see §7).

## 3. Budget & compression engine
`Logic/BudgetRecalculator.recompute(sessions:availableMinutes:)`, run on every deck `load()`:
- **Reserve** (never compressed): `.moment` + `.anchored` pending sessions keep their base minutes.
- **Compress** (flex): `.duration` pending sessions shrink proportionally into `pool = max(0, available − reserved − consumed)`, floored at `max(5, ceil(base*0.3))`.
- **Spent** only grows: completed sessions log `actualMinutes`; the running session's live elapsed is added in the view via a `TimelineView`.
- Habits are streak items → **never deferred** (the defer branch was removed; `SessionStatus.deferred` is vestigial, always 0).
- Detailed algorithm: [specs/elastic_compression.md](../specs/elastic_compression.md).

## 4. Day window & notifications
`Logic/DayWindow.swift`:
- **`DayWindow`** (Codable value): `startMinuteOfDay`, `endMinuteOfDay`, `windDownMinuteOfDay?`, **`budgetMinutes`**, `notificationsEnabled`. `resolvedWindDownMinute` = explicit, else `end − 60` (never before start).
- **`DayWindowStore`** — UserDefaults JSON. A device preference; **not** synced.
- **Budget is decoupled** from the window length — an explicit user input (default 120), read into `DailyDeckViewModel.availableMinutes`. Budget ≠ waking hours; fixed blocks (job/sleep) are *subtracted*, never budgeted. See [ADR-006](decisions.md).
- **`DayNotificationScheduler.plan(for:)`** (pure) → ≤2 nudges (day-start, wind-down). **`DayNotificationService`** (UN wrapper) requests auth, clears stale by id, schedules repeating `UNCalendarNotificationTrigger`s.
- Editing UI: `Settings → Day & budget` (`DayBudgetSettingsView`).

## 5. Evening reflection prompt
`Logic/EveningPromptPolicy.swift` (pure): `shouldSurface(nowMinute:windDownMinute:resolvedCount:unresolvedCount:)`:
- Surfaces once the clock passes wind-down (regardless of outcome — wins matter as much as losses), **or** early when everything's resolved (≥1 resolved, 0 unresolved; vacuous-truth guarded).
- **No screen takeover.** `DailyDeckView` shows a dismissible "Wind down" card atop the deck; "Reflect" opens `EveningRitualView` in a sheet. Dismissal sticks for the day (`@AppStorage` start-of-day stamp).
- Timing source = `DayWindowStore().resolvedWindDownMinute`. No hardcoded hour, no sunset (see [ADR-003](decisions.md)).

## 6. Journal E2EE
`Logic/JournalCrypto.swift` + `Logic/JournalKeyStore.swift`:
- **Field-level encryption** of `Journal.summaryNote`. `JournalCrypto.seal/open` — CryptoKit **AES-GCM**, payload `"wpx1:" + base64(combined)`. Non-deterministic (per-seal nonce).
- **Key**: 256-bit, in the **Keychain** (`AfterFirstUnlock`, **not** iCloud-synced, never exported), get-or-created by `JournalKeyStore`.
- The note is **sealed before it touches SwiftData or sync** → ciphertext is the at-rest value locally *and* in Supabase. No server/AI/provider can read it.
- **Legacy plaintext** (unmarked) passes through `open` untouched. **Wrong key/corruption** → `open` returns nil; UI shows a "locked" placeholder, never garbage.
- **Trade-off**: lose the device key ⇒ past notes unreadable (surfaced, not silent). See [ADR-002](decisions.md).
- Recap: `Logic/OnThisDaySelector.swift` (pure, same month+day prior years) → `MemoriesView` (decrypt on the fly).

## 7. Sync
- **DTOs** (`Supabase/SyncDTO.swift`) mirror tables in snake_case; **mappers** in `SyncMapping` (pure, unit-tested); orchestration in `SyncCoordinator.syncNow()` (pull → LWW-merge → push → advance watermark cursor).
- **LWW** on `updatedAt`; **soft-delete** tombstones on `deletedAt`; per-user **RLS** (`user_id default auth.uid()`).
- **Additive, backward-compatible migrations only** (`add column … default` / nullable; `decodeIfPresent` in DTO `init(from:)`) — commercial posture, see [ADR-001](decisions.md).
- **Incremental watermark**: `cursor.lastSyncAt` (UserDefaults). ⚠️ Wiping the local DB without clearing the cursor skips a full re-pull — delete-app/reinstall for a true re-hydrate (see test B5).
- **Automatic** sync runs on app foreground (§8); manual "Sync now" remains in Settings.

## 8. Production hardening
- Dev tooling (Settings → Data + Debug sections: re-seed / reset / force-evening / force-day / manual rollover) is **`#if DEBUG`-gated** — absent from Release builds (verified).
- **Auto rollover + sync**: `HabitTrackerApp` observes `scenePhase`; on `.active` (when signed in) it runs the idempotent `JournalArchiver.rollover` catch-up + fire-and-forget `AutoSync.run`. Pairs with the midnight `BGAppRefresh`.

## 9. Testing strategy
- **Harness-first hard gate**: a failing test precedes any new logic. View logic is extracted into pure, testable functions (`BudgetRecalculator`, `EveningPromptPolicy`, `JournalCrypto`, `OnThisDaySelector`, `DayWindow`, `MinutesInput`, …).
- 176 tests. Run: `make test` (or `xcodebuild test -scheme HabitTracker -destination 'platform=iOS Simulator,name=iPhone 17'`).
- Sim flake: first run may fail "Busy/preflight" — `xcrun simctl shutdown all` and rerun; not a code bug.