# Implementation Plan - Personal Habit & Project Tracker

> **Role (SDLC):** this file is the append-only **engineering changelog** — every
> phase, what shipped, test counts. For the *forward* view and *design* docs see
> [`docs/`](docs/README.md):
> [backlog](docs/product/backlog.md) ·
> [test plan](docs/product/test-plan.md) ·
> [tech spec](docs/architecture/tech-spec.md) ·
> [decisions/ADRs](docs/architecture/decisions.md).

## Project Vision
A specialized iOS app for "Time-Budgeting" instead of "Time-Scheduling". Focus on dynamic re-ordering based on energy levels and project progress tracking without rigid hour-constraints.

## Core Pillars (Harness Requirements)
- **Functional**: All core logic must have corresponding XCTests.
- **Data**: SwiftData for offline-first; Supabase for cloud-sync.
- **UX**: Zero friction. Re-sorting should be 1-tap.

---

## Phase 1: The Core Harness (Foundation) [DONE]
- [x] Project scaffolding (SwiftUI + SwiftData).
- [x] Folder structure (`Sources/`, `Tests/`, `docs/`) + Hello World harness test.
- [x] **Task 1.1**: Define Schema (Goals, Projects, Habits, DailyLogs) — `@Model` types + `AppSchema` container helper. 8 tests green.
- [x] **Task 1.2**: `DataRepository` protocol + `SwiftDataRepository` impl. 11 tests green.
- [x] **Task 1.3**: `MockRepository` (array-backed `DataRepository`) + error injection. 4 tests green.
- **Harness**: `DataLayerTests.swift` ✅, `RepositoryTests.swift` ✅, `MockRepositoryTests.swift` ✅

## Known Issues
- Heterogeneous `[Goal, Project, Habit, DailyLog].forEach(context.insert)` doesn't type-check; insert each entity individually or use a `[any PersistentModel]` array.
- `SwiftDataRepository` must hold the `ModelContainer`, not just its `ModelContext` — without a strong ref to the container, `context.save()` traps (`EXC_BREAKPOINT`) once the container is released.
- Widget extension uses an App Group (`group.com.willpower.HabitTracker`) for the shared SwiftData store. On a real device this requires the App Group capability to be registered on the developer account; the simulator falls back gracefully (still backed by a synced URL when the group container resolves).

## Phase 2: The Budgeting Engine (Logic) [DONE]
- [x] **Task 2.1**: `BudgetCalculator` — `BudgetSummary` (scheduled, remaining, isOverBudget, utilization). 6 tests green.
- [x] **Task 2.2**: `HabitSorter.sort(byMatch:)` (distance + duration tiebreak) and `filter(matching:)`. 6 tests green.
- [x] **Task 2.3**: Milestone `@Model` (id, title, isCompleted, completedAt, order); `Project.progress` derives from milestones (no more raw counters). 4 progress tests + 1 cascade test green.
- **Harness**: `LogicEngineTests.swift`

## Phase 3: The Daily Deck (UI) [DONE]
- [x] **Task 3.1**: `DailyDeckView` + `HabitCardView` + `DailyDeckViewModel`. Persisted `Habit.order`, drag-reorder via `.onMove`, 1-tap energy-sort toolbar menu, budget header. 5 VM tests green; app launches clean on iPhone 17 sim.
- [x] **Task 3.2**: `ProjectDashboardView` + `ProjectRowView` + `ProjectDashboardViewModel`. Grouped by Goal, overall progress header, per-project milestone bars. TabView in `RootView`. 3 VM tests green; app launches clean.
- [x] **Task 3.3**: `Habit.minutesLogged(on:)` helper, `DailyDeckViewModel.logCompletion(for:)`, tappable log button on `HabitCardView` (checkmark when logged today; subtitle switches to "Logged N min today"). 3 new tests green.
- **Harness**: SwiftUI Preview Snapshots & UI Tests.

## Phase 4: Live Momentum (iOS Features) [DOING]
- [x] **Task 4.1**: `HabitTrackerWidget` app-extension target wired via project.yml (embed + sign). `Sources/Shared/HabitActivityAttributes.swift` shared with main. `ActivityKitLiveActivityController` + `MockLiveActivityController` behind `LiveActivityController` protocol. `ActiveHabitSession` `@Observable` start/stop/elapsed with 8h cap and injectable clock. Lock-screen UI + minimal DI regions in `HabitLiveActivityWidget`. Play/stop button on each `HabitCardView`. 6 session tests green; widget extension builds and embeds.
- [x] **Task 4.2**: `DeepLink` (`willpower://habit/<UUID>`) parser in `Sources/Shared`, 4 round-trip tests. `widgetURL(_:)` set on lock-screen, DI bottom region, and `NextBestActionWidget`. `context.isStale` dims energy dot/progress bar, hides timer (`--:--`), surfaces "Tap to resume". `RootView` adds `.onOpenURL` → switches to Today tab + sets `focusedHabitID`. `DailyDeckView` now takes `focusedHabitID: Binding<UUID?>`, scrolls + highlights the row.
- [x] **Task 4.3**: `NextBestActionSelector` (pure: skip fully-logged, pick by energy match, shorter-duration tiebreak). `NextBestActionWidget` (`StaticConfiguration`, small/medium) with `Button(intent:)`. `LogHabitIntent` (`AppIntent`) inserts `DailyLog(durationMinutes: estimatedMinutes)` and saves. App Group `group.com.willpower.HabitTracker` shared between app + widget; `AppSchema.sharedContainer()` points SwiftData at the group URL. 5 selector tests green; 51 total. Widget extension builds + embeds.

## Phase 5: Cloud Sync (Supabase) [DOING]
- [x] **Task 5.1 (email OTP)**: `supabase-swift` SPM dep pinned `from: 2.0.0` (resolves to 2.46.0). `SupabaseConfig.fromBundle()` reads `SUPABASE_URL`/`SUPABASE_ANON_KEY` from Info.plist sourced via gitignored `Supabase.xcconfig` (example committed). `AuthService` protocol + `SupabaseAuthService` (actor wraps `supabase-swift`) + `MockAuthService`. `LoginViewModel` (`@Observable @MainActor`) drives `email → code → signedIn`. `LoginView`/`AccountView` + third "Account" tab. 5 VM tests green; 60 total.
- [x] **Task 5.1b (Apple Sign-in)**: `com.apple.developer.applesignin` entitlement added. `AuthService.signInWithApple(idToken:nonce:)` wraps `client.auth.signInWithIdToken(.apple)`. `AppleNonce.make()` (CryptoKit SHA-256) hashed nonce in `ASAuthorizationAppleIDRequest`, raw nonce sent to Supabase. SwiftUI `SignInWithAppleButton` in `LoginView`. 3 nonce tests + 2 VM tests; 78 total.
- [x] **Task 5.2**: Deno Edge Function `supabase/functions/progress-report` (`?range=week|month`) aggregates `daily_logs` + `milestones` over the trailing window scoped by caller JWT → `{ total_minutes, session_count, milestones_completed, top_habits[5], by_day[] }`. Swift client: `ReportsService` protocol + `SupabaseReportsService` (`client.functions.invoke` with iso8601 decoder) + `MockReportsService`. `ReportsViewModel` (`@Observable @MainActor`) + `ReportsView` with segmented week/month picker + summary/top-habits/by-day sections; 4th "Reports" tab. 4 tests including a JSON shape regression locked to the function's wire format. 73 total.
- [x] **Task 5.3 (manual, LWW)**: `updatedAt` added to all `@Model`s (default `Date.distantPast` for migration); repo writes bump it. `SyncDTO` Codable structs (snake_case) + `SyncMapping` pure converters + `remoteWins(local:remote:)`. `SyncService` protocol with `SupabaseSyncService` (PostgREST upsert + `gt updated_at`) and `MockSyncService`. `SyncCoordinator.syncNow()` orchestrates pull→LWW-merge→push→advance-cursor; pluggable `SyncCursor` (`UserDefaults` + `InMemory`). SQL schema in `docs/supabase/migrations/001_initial.sql` (5 tables, RLS owner-only). "Sync now" button in `AccountView`. 9 sync tests green; 69 total.
- [x] **Task 5.3b (soft-delete + realtime)**: `deletedAt: Date?` on all 5 `@Model`s. Repo `delete(_:)` is now soft (sets `deletedAt + updatedAt`); all `fetch*` filter tombstones. `Project.activeMilestones` / `Habit.minutesLogged` ignore deleted. Coordinator merge writes `deletedAt` LWW on existing rows, refuses to materialize never-seen tombstones, and pushes local tombstones in `collectLocal`. `RealtimeSync` actor (`RealtimeChannelV2`) subscribes to row-level changes across the 5 tables and pings a callback; "Live sync" toggle in AccountView debounces into `runSync()`. 5 soft-delete tests + existing sync tests still green; 83 total.

---

## Known Issues & Constraints
- *Constraint*: SwiftData & Supabase sync conflicts — `updated_at` LWW + soft-delete tombstones on `deleted_at`. Old tombstones accumulate forever client-side; consider a periodic local prune for rows where `deletedAt < now - 30d`.
- *Risk*: Live Activities timeout after 8 hours (Need to handle long-running habits).

## Phase 6: Auth UX overhaul [DOING]
- [x] **Task 6.1**: Carve auth out of Account/Login soup into a self-contained `Sources/HabitTracker/Auth/` module. `AuthCoordinator` (`@Observable @MainActor`, state machine: `checking → signedOut → signedIn(UUID)`) is the single source of truth, owned at app root. `HabitTrackerApp` body switches between `SplashView`/`AuthRootView`/`RootView` based on `coordinator.state`. `AuthRootView` is a single-screen email gate (hero + inline form), full-screen replacement (not a tab). `Account` tab renamed to **Settings** with Profile / Sync / About / Sign-out sections.
- [x] **Task 6.2**: Trimmed v1 auth surface to email-only. Removed Apple Sign-in (`com.apple.developer.applesignin` entitlement, `AppleNonce`, `signInWithApple` from `AuthService`/`MockAuthService`, `SignInWithAppleButton`); collapsed `AuthRootView` from method-picker + pushed `EmailLoginView` into a single inline form. 81 tests green.
- [ ] **Task 6.3 (deferred)**: Login with Google — requires Google tax info on the developer account.
- [ ] **Task 6.4 (deferred)**: Phone OTP — requires paid SMS provider (Twilio etc.) configured in Supabase.
- [ ] **Task 6.5 (deferred)**: Apple Sign-in — requires paid Apple Developer Program + Service ID + .p8 key configured in Supabase.

## Phase 7: Create/Edit/Delete UX (MVP unblocker) [DOING]
**Why**: Phases 1–6 shipped data + sync + auth but no way to *add* a row. Calling it MVP was wrong.
- [x] **Task 7.1–7.4**: 4 editor VMs (`Goal`/`Project`/`Milestone`/`Habit`) each with `.create`/`.edit` modes + `isValid` + async `save() -> Bool`. 4 sheets (`HabitEditorSheet` standalone, others in `EditorSheets.swift`). New `ProjectDetailView` drill-in (habits + milestones with per-section + buttons, tap-to-edit, swipe-to-delete). `ProjectDashboardView` got + Goal toolbar, + Project per goal-header, NavigationLink rows, swipe-to-delete. `DailyDeckView` got + Habit toolbar (smart: prompts to create a project first if none), tap-to-edit, swipe-to-delete, `ContentUnavailableView` empty-state with primary CTA. `DemoSeeder` seeds 3 goals × 1 project × 3 habits + 1 milestone each on first launch (UserDefaults-keyed, idempotent, skips if any data exists). 6 new tests; 89 total.

## Phase 8: Profile tab (Instagram-style) [TODO]
**Why**: Settings-as-identity is generic and lazy. Profile-as-identity is how Instagram/Linear/Notion do it.
- [x] **Tasks 8.1–8.4**: New `Sources/HabitTracker/Profile/` (`ProfileView`, `ProfileViewModel`, `StreakCalculator`). Tab renamed Settings → **Profile**. Header: colored circular avatar with initials, display name (UserDefaults-backed `EditDisplayNameSheet`), placeholder email derived from UUID. 3-stat row: streak / total hours / milestones. Active-projects mini-list with progress bars. Gear icon top-right pushes a slimmed `SettingsView` (Sync / Data / About / Sign-out). 5 streak tests.
- [ ] **Task 8.5 (deferred)**: Real `Profile` `@Model` synced via Supabase. Currently UserDefaults-local.

## Phase 9: Schema split + timer auto-commit [TODO]
**Why**: from v2's good ideas — unlocks accuracy analytics + fixes a real bug.
- [x] **Tasks 9.1–9.4**: `DailyLog.expectedMinutes: Int?` added (storage `durationMinutes` retained as "actual" for lightweight migration; `actualMinutes` is a computed alias). `Milestone.weight: Double = 1.0` + `Project.weightedProgress`. `DailyDeckView` toggle-stop now auto-commits a `DailyLog(actual: elapsed, expected: habit.estimatedMinutes)` when ≥ 1 minute elapsed. SQL migration `20260523000000_phase9_schema_split.sql` (pushed to prod). `progress-report` Edge Function deployed v2 with `estimation_accuracy`. `ReportsView` Summary section shows accuracy when non-nil. 7 new tests (5 streak + 2 weighted progress + accuracy JSON shape); 96 total.

## Phase 10–18: v3 ("Action OS") rollout [DOING]
**Approach**: surgical replacement (B). Keep auth/sync/widgets/build/reports plumbing; swap domain layer + main UI. Spec docs: `docs/specs/elastic_compression.md`, `docs/specs/discipline_score.md`.

- [ ] **Phase 10**: Focus mode — single-card next-best-action surface, complements Today list.
- [x] **Phase 11**: Execution layer. New `DailySession` model (`baseMinutes` / `compressedMinutes` / `actualMinutes?` / `status` enum / `isInterruption` / `orderHint` / `note`). `Habit.priority` added. `DailyLog` and `daily_logs` table dropped (pre-PMF clean break). `SessionGenerator` materializes pending sessions from active habits idempotently. Repository protocol replaced `fetchLogs`/`add(log:)`/`delete(log:)` with session equivalents (`fetchSessions(on:)`, `fetchAllSessions()`, `add(session:)`, `delete(session:)`). Deck VM/View rewritten around sessions (pending + completed sections, no sort menu — orderHint is intentional). `HabitCardView` → `SessionCardView` showing compressed vs base. Widget Intent (`LogHabitIntent`) now finds-or-creates today's session and marks completed. NextBestActionSelector picks sessions (interruption first, then priority). StreakCalculator + ProfileViewModel rewired to sessions. Sync DTO/Mapping/Coordinator/Service/RealtimeSync all swap `logs` → `sessions` / `daily_logs` → `daily_sessions`. SQL migration `20260526000000_phase11_daily_sessions.sql` pushed (drops `daily_logs`, creates `daily_sessions` with status enum + indexes + RLS). Edge Function `progress-report` deployed v3 — queries `daily_sessions` where `status=2`, accuracy uses `base_minutes` vs `actual_minutes`. 87 tests green.
- [x] **Phase 12**: `BudgetRecalculator` shipped per spec. Strategies: `.shrinkAll` (default proportional) + `.dropLowest`. Floor = `max(5, ceil(base*0.3))`. Trigger: on every `DailyDeckViewModel.load()` (after add/complete/inject). Sessions get `.deferred` when sum-of-floors > remaining (lowest priority first). 6 tests.
- [x] **Phase 13**: `InterruptionInjectorSheet` (orange ⚡ toolbar leading on Today). Title + presets (15/30/60) + custom stepper. Creates `DailySession(isInterruption: true)`, triggers recompute. Deferred section appears as "Bumped to tomorrow" on the deck.
- [x] **Phase 14 (partial)**: `DisciplineScorer` pure scorer per spec (1.0/0.7/0.5/0.0 ladder, deferred excluded, interruption excluded, energy-weighted day aggregate, streak threshold 0.6 with grace days). ProfileVM stat card "Total time" → **"Discipline today"**. `Journal` `@Model` deferred to Phase 15 (Evening Ritual needs the persistence; today's score is computed live). 8 tests.
- [x] **Phase 15**: `EveningRitualView` swapped in post-8PM via `Calendar.component(.hour) >= 20`. `LabelledProgressRing` discipline hero, completed/interruptions/bumped count cards, optional reflection note. Note saves into `Journal.summaryNote` via `JournalArchiver.archive()`. Tone-of-voice copy ladder ("Crushing it" → "Reset. Tomorrow is fresh"). Tab title flips Today → Tonight.
- [x] **Phase 16 (full)**: `JournalArchiver.archive(day:)` + `.rollover()` + manual Settings button. **Auto-trigger live**: `BGAppRefreshTaskRequest` registered with id `com.willpower.HabitTracker.midnightRollover`, `earliestBeginDate = next midnight`. Wired via `.backgroundTask(.appRefresh)` in `HabitTrackerApp` body. `MidnightRollover.handle` calls archiver + reschedules. `project.yml` adds `BGTaskSchedulerPermittedIdentifiers` + `UIBackgroundModes: [processing]` to Info.plist (per user approval). iOS fires opportunistically — empirically lands in early-AM hours, sometimes skipped if device is asleep.
- [x] **Phase 17**: Saner-style LLM ingestion. Edge Function `task-ingest` deployed — forwards text to Gemini 2.5 Flash via Google AI Studio (free tier), strict JSON output parsed into `IngestProposal { habits, milestones, interruptions }`. iOS client: `SupabaseTaskIngestService`, `MockTaskIngestService`, `IngestionViewModel`, `IngestApplier` (pure, project-hint matching), `IngestionSheet` (text field + per-item accept toggle + voice dictation via `VoiceDictator` wrapping `SFSpeechRecognizer`). "Brain dump" entry under the Today + menu. Privacy strings + Speech/Mic permissions added to Info.plist. 4 applier tests. **User action needed**: `make supabase-secret-set NAME=GEMINI_API_KEY VALUE=<from aistudio.google.com>` (or `supabase secrets set GEMINI_API_KEY=...`) before LLM actually runs.
- [x] **Onboarding**: 3-screen first-launch tour (`OnboardingView`) — Vision / Energy / Live Activity. `UserDefaults.didShow.v1` keyed, skippable. Shown before auth.
- [x] **Per-session note UI**: italic caption when `session.note` is set; interruptions get a ⚡ icon prefix. Non-interruption note-setting UI deferred to a session-detail sheet (next polish pass).
- [x] **A11y pass**: combined accessibility labels on `SessionCardView` ("title, subtitle"), distinct labels on session play/stop + complete buttons, "Completed" label on the done checkmark. Dark mode inherits via system colors throughout. 110 total tests.
- [x] **Phase 18**: `ProgressRing` + `LabelledProgressRing` Shape components. `Haptics.tap()` / `.success()` (UIImpactFeedbackGenerator / UINotificationFeedbackGenerator). ProjectRow swapped linear bar → ring. Session complete + timer-start both haptic. 3 journal tests; 106 total.
- [x] **Sync gap closed**: `Journal` now in `SyncDTO`/`SyncMapping`/`SyncCoordinator` (push + LWW merge), RealtimeSync subscribes to `journals` channel, SQL migration `20260527000000_phase15_journals.sql` pushed (`unique(user_id, date)`, RLS owner-only).
- [x] **Debug toggle**: Settings → Debug → "Force evening ritual" (`@AppStorage`-backed) so the Tonight layout is previewable without changing system clock.
- [x] **Debug toggle (day)**: Settings → Debug → "Force day mode" peer toggle; mutually exclusive with Force evening. Escape hatch for testing the deck after 8PM (`willpower.debug.forceDay`).
- [x] **Phase 19 — Session controls rework (Tier 2)**: Manual test pass surfaced 4 bugs in the running-habit loop. Root cause: `ActiveHabitSession` had only start/stop (no pause), and complete/delete paths never called `stop()`, so the Live Activity + ring kept counting on completed/deleted habits.
  - Added real `pause()`/`resume()`: `startedAt` shifts forward by the paused span so elapsed + ring + overrun timer resume exactly where they left off. `elapsedMinutes` freezes at `pausedAt`.
  - `ContentState.pausedAt` (Shared) added; `pause/resume` push `controller.update`. Widget (lock screen + Dynamic Island) freezes the timer and shows "Paused" + a `pause.fill` glyph instead of a live `.timer`.
  - Card now has **3 distinct controls** when a session is active: Pause/Resume (toggle) · Stop (red, abandon w/o logging → `resetToPending`) · Done (logs actual elapsed via `completeSession`, then `stop()`). Completion is **done-checkbox only** — the play/pause button never completes or discards.
  - Swipe-delete and Done both call `stop()`/`stopIfRunning` so the Live Activity always tears down. In-app ring greys + shows `❙❙` while paused.

- [x] **Phase 19.1 — test-pass bugfixes** (manual QA round 2):
  - **#4 budget logic (critical)**: `DailyDeckViewModel.totalScheduledMinutes` summed `compressedMinutes` for *all* non-deferred sessions, so completed habits contributed their estimate, not actual logged time. Now completed → `actualMinutes`, live → `compressedMinutes` (mirrors `BudgetRecalculator`). Regression test added.
  - **#5 Live Activity estimate**: `ActiveHabitSession.start` built the `ContentState` from raw `habit.estimatedMinutes` while the ring used the compressed budget — lock screen showed "Estimated 10 min" for a 5-min session. Now both use the passed `effectiveBudget`.
  - **#3 Stop = log partial** (user choice): Stop no longer abandons silently. It logs elapsed minutes and marks the session `completed` + `stoppedEarly`; `DisciplineScorer` already scores partials proportionally (0.7/0.5/0.0). New `DailySession.stoppedEarly` field (SwiftData lightweight add, defaulted false). Card shows "Logged X min · stopped early" with an orange ⚠️ badge. `resetToPending` removed.

- [x] **Phase 19.2 — sync `stopped_early`**: Added to `SyncDTO.DailySession` (snake_case `stopped_early`) with a back-compat `init(from:)` so pre-column Supabase rows decode as `false`. Wired through `SyncMapping.dto` + both `SyncCoordinator` apply paths. Migration `20260607000000_phase19_stopped_early.sql` (additive, default false) pushed to remote via `make db-push`. Tests: round-trip + legacy-row decode (111 total).

- [x] **Phase 20 — Today tab restructure** (manual QA round 3, user-specced):
  - **Budget = time spent (only grows)**: `BudgetSnapshot` is now `spentMinutes` (sum of actual logged across completed) + `plannedMinutes` (compressed of pending). Header reads "Spent X / 120 min · Y planned" and adds the running session's **live** elapsed via a `TimelineView`. Stopping always *adds* the elapsed (no more estimate→actual drop). `totalScheduledMinutes` removed.
  - **Section order**: Today's budget → **Going on** (the one active session) → **Up next** (pending) → **Completed** → **Bumped**. New `goingOnSessions`/`upNextSessions`/`deferredSessions` accessors.
  - **One running at a time**: `markActive` demotes any other `.active` session back to pending.
  - **Resume** (under-target completions): card shows a ▶; `reopen(_:active:)` clears completion and continues from logged minutes via `ActiveHabitSession.start(resumingFromMinutes:)`. Starts in Going on if nothing running, else Up next.
  - **Repeat** (at/over-target): swipe-left reveals a Repeat action → confirmation dialog ("you've already done enough… today") → `repeatHabit` clones a fresh run; auto-starts (Going on) when nothing's running, else Up next.
  - **Badges**: under-target ⚠️ orange "stopped early" + "Logged X / Y min"; on-target ✓ green; over-target 🔵 "arrow.up.circle" + "Logged X min · +Z over".
  - **Collapsible sections**: Up next / Completed collapse to header + count (expanded by default); Going on + budget never collapse.
  - Tests: +5 (spent accounting, reopen, one-running, repeat clone) → 114 total.
- [x] **Phase 20.1 — remove deferral ("Bumped")**: Habits are streak items, never deferred (TickTick/Things 3/Habitica don't defer habits). `BudgetRecalculator` no longer produces `.deferred` — removed the defer branch + unused `dropLowest` strategy + the `Strategy` param; over-scheduled days just shrink everyone to floor and run over. Removed the "Bumped" section (DailyDeckView), the evening-ritual "Bumped" stat, and the card's deferred rendering. `SessionStatus.deferred` enum case + `Journal.deferredCount` kept (no churn; always 0 now). Compression (the "(was XX)" shrink) left intact for the future AI flow. Two deferral tests rewritten to assert shrink-to-floor/no-defer.

- [x] **Phase 20.2 — Today tab QA round 4** (manual QA):
  - **#1 clean-slate reset**: Added `DemoSeeder.resetToHabitsOnly` (hard-wipes OKR graph + sessions + journals + habits, re-seeds the 4 standalone habits) wired to a destructive "Reset to habits only (0/120)" action in Settings → Data. Gives a deterministic 0/120 budget for QA. (The "7-min habit only +1 spent" report is the time-spent model working as designed: completing the *running* habit logs actual elapsed, which was ~1 min — completing from the checkbox without running logs the planned minutes.)
  - **#2**: Renamed Today's budget section header → "Budget" (the mega banner is already "Today").
  - **#3**: Budget bar copy clarified — "N of 120 min spent" + "M min to go" (was the ambiguous "M planned"; "to go" = sum of Up next compressed minutes, which is why it can be large relative to habit count).
  - **#4**: Collapse headers reworked — leading rotating disclosure chevron (tinted), inline `(count)`, and a "Show" hint when collapsed, so the header reads as the control for the list below.
  - **#5**: Bonus-rep badge — `DailyDeckViewModel.extraRunSessionIDs` flags 2nd+ runs of the same habit today; `SessionCardView` shows an indigo "BONUS" pill + "Bonus rep · logged X min" subtitle in Completed so repeated/over-done habits are noticeable. (Time-over-target keeps its blue ↑ badge.)

- [x] **Phase 20.3 — Today tab QA round 5** (manual QA, 9 items):
  - **#1/#2 CRITICAL — switch-while-running dropped time**: starting habit B while A ran called `session.stop()` + `markActive` (demote-to-pending) with **no logging** — A's real elapsed was lost. Now `toggleSession` raises a confirm **alert** ("Finish A first?"); `confirmSwitch` completes A logging `max(1, elapsed)` **flagged `stoppedEarly: true`** (user ended it before target) then starts B. No silent-drop path remains.
  - **#3 alert UI**: Repeat/"do it again" moved from `.confirmationDialog` (rendered as a stray top popover with no Cancel) to a native `.alert` — centered, dimmed, Cancel present.
  - **#4 edit Up-next habit**: added blue **Edit** swipe action on pending rows → `HabitEditorViewModel(.edit)`. Pending sessions now mirror their habit's estimate via `syncPendingEstimates()` on load, so edits/duration changes reflect in Up next.
  - **#5a clone double-ring**: running state was keyed on `activeHabitID`, so a bonus clone sharing the habit id lit a ring on the *completed* original too. Added `ActiveHabitSession.activeSessionID`; all row/handler checks now key on **session id**.
  - **#5b/#5c/#9 pills**: BONUS + target pills moved next to the habit name (order: name → BONUS → target); removed the "Bonus rep" subtitle line and the right-side over/under icons.
  - **#6 subtitle**: completed cards read `X/Y min · energy` (actual / target).
  - **#7 wording**: "stopped early" → **Under target**; over → **+N over** pill.
  - **#8 duration**: habit editor now has a free numeric field (min 1, e.g. 2–3 min) plus a "+/− by 5" stepper, instead of a 5-step-only stepper. Fixed the stale "compressed or bumped" footer.
  - **#1 header**: removed the "Show" label; moved the disclosure chevron to the right so section titles are left-aligned.

- [x] **Phase 20.4 — Today tab QA round 6** (manual QA, 3 items):
  - **#1 confirm Up-next completion**: tapping done (○) on an Up-next habit no longer logs silently — raises a "Did you do \<habit>?" alert ("logs N min toward today's budget"); only "Yes, I did it" calls new `completeAsPlanned(_:)` (logs the compressed estimate as a full completion). Running habit's done button unchanged (logs real elapsed). Test: `test_completeAsPlanned_logsEstimateIntoBudget`.
  - **#2a badge consolidation**: all name-row badges (BONUS / over / under) routed through one `pill()` style — uppercase, fixed 18pt height, shared kerning/weight/shape, single line — so they read as one family.
  - **#2b unit**: over-target pill "+N over" → "+N MIN OVER".

- [x] **Phase 20.5 — Today tab QA round 7** (manual QA, layout):
  - **#1a/#1b**: removed the leading bolt + trailing "+" toolbar items; single **floating "+" menu** bottom-right above the tab bar, order Inject interruption → Brain dump → Add habit.
  - **#2a/#2b**: budget + progress bar moved into a hero **"Today's budget"** card (united the old "Today" title + "Budget" section header); nav title now `.inline`. Card background is a swappable `budgetCardBackground` view — the seam for #2c.
  - **#2c (background customization)** — chosen approach: **Supabase-hosted assets**. Built in 2 increments:
    - **Increment 1 (DONE)**: app-side foundation. `CardBackground` Codable enum (`.surface`/`.solid(hex)`/`.remote(path)`/`.local(filename)`) + `Color(hex:)`; `CardBackgroundStore` (UserDefaults) + `LocalImageStore` (Application Support); `BackgroundPickerSheet` (Colors | Stock | Upload, PhotosPicker); paintbrush button on the card; `budgetCardBackground` renders all cases with a legibility scrim + white text over images. Colors use a bundled `defaultColorBoard` placeholder; Stock tab is a "loads from server" placeholder. 4 tests (`CardBackgroundTests`).
    - **Increment 2 (DONE)**: migration `20260609000000_phase205_backgrounds_bucket.sql` creates the public `backgrounds` bucket + `storage.objects` public-read policy (pushed to remote). `BackgroundCatalog` (decode `colors.json` object/array forms; map storage object names → `stock/` image paths) + `BackgroundCatalogStore` cache + `BackgroundCatalogProviding` / `SupabaseBackgroundCatalogService` (Storage `download` + `list`) / `MockBackgroundCatalogService`. Picker loads cached-then-fresh; Colors tab is server-driven, Stock tab renders `stock/*` via public URL. Seed `supabase/storage/backgrounds/colors.json` (12 colors) uploaded + verified (HTTP 200 public read). `make backgrounds-upload` target added. 6 tests (`BackgroundCatalogTests`). **Remaining (user action only):** drop curated Unsplash images (calm/zen/peaceful/forest) into `supabase/storage/backgrounds/stock/` and run `make backgrounds-upload` — the Stock tab is empty until then.

- [x] **Phase 20.6 — Today tab QA round 8** (post-background polish):
  - **#1**: budget card now matches the Up-next list-section width (listRowInsets leading/trailing 16 → 20 to align with insetGrouped margins).
  - **#2**: progress bar was invisible over an image background (system `ProgressView` track washed into the scrim at fill 0). Replaced with a custom capsule `progressBar` — visible white-opacity track on images, `systemGray5` on surface. Fraction extracted to `BudgetSnapshot.fraction(spent:available:)` (clamped [0,1], guards zero-available) with a unit test (`test_budgetFraction_clampsAndGuardsZeroAvailable`).
  - **#3**: nav header "Today" → brand lockup (`brandHeader`: accent `flame.fill` app mark + "WillPower" wordmark) via `.principal` toolbar item; evening still shows "Tonight".

- [x] **Phase 20.7 — Today tab QA round 9** (budget card alignment polish):
  - **#1**: budget card width now driven by `.listRowBackground(budgetCardBackground)` instead of a self-drawn rounded rect at a guessed inset — the system positions/clips it to the exact insetGrouped section shape, so it lines up perfectly with the Up-next card. Content uses default row insets (matches Up-next content). `budgetCardBackground` solid/surface cases now fill edge-to-edge (system rounds the cell; no double-round).
  - **#2**: budget card ~20% taller — added `.padding(.vertical, 14)` to the card content for hero whitespace.
  - **#3**: brand wordmark "WillPower" → "Will Power" (spaced, no CamelCase). Note: home-screen icon label is `CFBundleName = $(PRODUCT_NAME)` = "HabitTracker" (not user-facing brand); changing it needs an Info.plist `CFBundleDisplayName` edit — deferred pending confirmation.

- [x] **Phase 20.8 — Inject interruption duration UI consolidation**: the interruption sheet's "How long will it take?" used a 15/30/60 segmented quick-pick + "Custom" stepper, inconsistent with the normal Add-habit editor. Replaced with the editor's exact pattern — free-entry "Estimated" numeric `TextField` + "Adjust by 5" `Stepper` (1...600) + the same footer copy. Pure UI; no logic change.

- [x] **Phase 20.9 — Inject interruption bugfix + glyph**:
  - **#1 numeric input**: duration `TextField(value:format:.number)` accepted non-digits (sim hardware keyboard) and could collapse to a stray value. Replaced with a digits-only String field backed by `MinutesInput` (Logic/): `sanitize` strips non-digits + caps 3 chars; `minutes(from:)` parses → clamps to 1...600 → fallback 15 (never a tiny stray). Stepper drives an Int `minutesBinding` onto the same text. 4 tests (`MinutesInputTests`).
  - **#2 leading glyph**: the injected-interruption row now shows `bolt.fill` **in place of** the energy dot (`leadingGlyph`), tinted by `energyColor`; removed the redundant inline bolt next to the title. NOTE: interruptions carry no energy (no `habit`) so `energy` defaults to `.mid` → bolt is always orange today. To make the color actually vary, the inject sheet needs an energy picker (offered, not yet built).

- [x] **Phase 20.10 — Duration UI compaction + section reorder + interruption energy**:
  - **#1 compact duration field**: new shared `MinutesField` view — `−  XX min  +`, number directly editable (digits-only via `MinutesInput`), −/+ step by **1** (was 5), clamped to 1...600 via new `MinutesInput.clamped`. Removed the separate "Adjust by 5" stepper row in both the editor and the inject sheet. (1 new test `test_clamped_boundsIntToRange`.)
  - **#2 Add-habit section order**: What → Energy → **Priority → Duration** (Duration moved last).
  - **#3 Inject section order + energy**: What just happened → **Energy** (new segmented picker) → How long will it take?. Interruptions now carry their own energy: added local-only `energyRaw`/`energy` to `DailySession` (synced DTO untouched; legacy/other-device rows default `.mid`); `DailySession.energy` returns `habit?.energy ?? own`. `injectInterruption(title:energy:expectedMinutes:)` + `InterruptionInjectorSheet.onInject` now pass energy through, so the leading bolt (Phase 20.9 #2) finally varies by the picked energy color. (1 new test `test_injectInterruption_storesChosenEnergyOnSession`.)

- [x] **Phase 20.11 — Interruption energy now syncs**: added `daily_sessions.energy_raw integer not null default 1` (migration `20260612000000_phase2010_session_energy.sql`, **pushed**). DTO gained `energy_raw` (legacy-tolerant `decodeIfPresent ?? mid`); `SyncMapping` + `SyncCoordinator` (update + insert) carry it. 2 tests (`testSessionEnergyRoundTrips`, `testSessionDecodesLegacyRowWithoutEnergy`). Verified existing per-user RLS on `daily_sessions` covers the new column. **Strategic note:** user is commercializing (aim $1M MRR) — from now migrations are additive/backward-compatible, multi-tenant by default. 138 tests pass.

- [x] **Phase 20.12 — Auth error taxonomy (C1)**: original "Couldn't reach the server" report was a **transient simulator network blip**, not a code bug — verified end-to-end sign-in works on-device (booted sim, captured console). Real durable defect was error *masking*: every non-rate-limit failure became `.network` ("check your connection"), lying about server-side problems. Fixed: new `AuthError.server` case; `SupabaseAuthService.classify` taxonomy (rate-limit → `.rateLimited`; true transport/`URLError`/`NSURLErrorDomain` → `.network`; everything else → `.server`) replaces `translate`; all catch blocks (sendOTP/verifyOTP/requestEmailChange/signOut) route through it + `OSLog`. VM `describe` gives `.server` its own honest copy. Removed the `#if DEBUG` stderr capture hack. 4 tests (`AuthErrorClassifierTests`). 144 tests pass. (D2 magic-link template: skipped — code arrives fine.)

- [x] **Phase 21 — Habit-kind foundation**: habits now carry a time-shape so the budget/compression engine and the post-onboarding AI workflow can classify them. `HabitKind` enum (`.duration`=0 / `.moment`=1 / `.anchored`=2) in `Sources/Shared/`; `Habit.kindRaw`/`kind` (default `.duration`); synced — migration `20260616000000_phase21_habit_kind.sql` (`habits.kind_raw int not null default 0`, **pushed**), DTO `kind_raw` with legacy-tolerant decode, `SyncMapping` + `SyncCoordinator` (update + insert). 3 tests. 147 pass. **Foundation only** — no editor UI / compression behavior yet (see spec below).

## Product Direction — Day Window + Journal + Evening (agreed 2026-06-16)
Strategic shift: WillPower differentiates as an **emotional memory vault**, not just a habit tracker. Decisions locked in debate with the user:

1. **User-set day window (start/end)** drives: (a) start/wind-down **local notifications** (≤2/day, value not nag); (b) it is *not* the habit budget. **Budget ≠ waking hours.** `discretionary budget = window − fixed blocks (job/sleep/meals) − ~0 moment-habits`. Budget stays an explicit user input (AI may default it). **Habit-kind (Phase 21) is the structural prerequisite** — duration consumes budget, moment ≈ 0, anchored = fixed block subtracted from the window. Editor UI + compression treating kinds differently are the next builds.
2. **Journal = the moat.** End-of-day reflection prompt, **outcome-agnostic** (wins deserve capture as much as losses — no negativity bias). Powers progress recap, "On This Day", year-in-review.
   - **Encryption: true E2EE.** Owner-only; readable only by owner + explicitly share-granted people. **No team/AI/training access, ever.** Decrypt valid only for the sharing edge case.
   - **Journal AI is on-device only** (Gemma/Llama-class, e.g. MLX/Core ML/llama.cpp) — **zero network egress** of journal data, no provider. Value: correlate *felt* (journal) × *did* (habits) → pattern surfacing, semantic recall, mood inference, year-in-review. Accept it's modest vs. frontier models — privacy > polish. **Opt-in server AI parked** as a clearly-labeled future toggle, never default.
   - Park family-sharing + posthumous handoff as north-star narrative; do not build until the core loop retains.
3. **Evening = surfaced prompt, never a screen-hijack mode.** Retire the hard 20:00 `isEvening` takeover.
   - Timing mirrors iOS auto light/dark: **user wind-down time wins; else local sunset** (from timezone/approx city — *not* GPS, to stay privacy-consistent). No hardcoded hour.
   - Early opportunistic nudge fires when **all planned habits are *resolved* (completed or skipped)** — guard vacuous truth (≥1 resolved, none pending) + ignore interruptions/bonus. This is a nudge, *not* the gate; the wind-down time fires the prompt regardless of success.

- [x] **Phase 21.1 — Habit-kind editor UI + kind-aware compression** (build-queue #1):
  - **Editor**: `HabitEditorSheet` gains a **Kind** segmented picker (Duration / Moment / Anchored) after "What", with kind-specific footer copy. Duration section is hidden for `.moment` (no time budget; saves `estimatedMinutes = 0`, `isValid` relaxed); labeled "Block length" for `.anchored`. Switching off moment restores 30 if minutes were 0. `HabitEditorViewModel` carries `kind`, `effectiveMinutes`, kind-aware `isValid`; persists on create + edit.
  - **Compression**: `BudgetRecalculator` now partitions pending by kind — `.moment`/`.anchored` keep base and **reserve** their minutes (never compressed); only `.duration` habits compress, into `pool = remaining − reservedMinutes`. `DailySession.kind = habit?.kind ?? .duration` (interruptions act as duration).
  - **Card**: moment sessions show "Quick check-in"/"Done" instead of "0 min".
  - 4 tests (`test_momentHabit_neverCompressed`, `test_anchoredHabit_reservesMinutesAndIsNotCompressed`, moment-valid + duration-requires-minutes). 151 pass.
  - **Deferred to day-window feature (#2):** anchored *time-of-day* (the actual clock anchor + timeline). Today anchored = a reserved, non-compressed block without a set time.

- [x] **Phase 22 — Day window + budget decoupling + notifications + anchored time-of-day** (build-queue #2):
  - **`DayWindow`** value type (`Logic/DayWindow.swift`): start/end minute-of-day, optional `windDownMinuteOfDay` (derives end−60, never before start), `budgetMinutes` (decoupled from window length — budget ≠ waking hours), `notificationsEnabled`. `DayWindowStore` (UserDefaults JSON, device-pref like card background — not synced).
  - **Notifications**: pure `DayNotificationScheduler.plan(for:)` → ≤2 nudges (day-start + wind-down) at the window's minutes; `DayNotificationService` (UN wrapper: request auth, clear stale by id, schedule repeating `UNCalendarNotificationTrigger`s). Disabled window = clear only.
  - **Budget decoupling**: `DailyDeckView` reads `DayWindowStore().current.budgetMinutes` into `viewModel.availableMinutes` in `.task` + on tab re-show (`.onAppear`, guarded). Budget is now a user input, not the hardcoded 120.
  - **Anchored time-of-day**: `Habit.anchorMinuteOfDay: Int?` (additive, nil = unanchored/legacy) — synced (DTO `anchor_minute_of_day` legacy-tolerant decode, mapping + coordinator update+insert, migration `20260617000000_phase22_habit_anchor.sql` **pushed**). Editor: `HabitEditorViewModel.anchorMinuteOfDay` (+`effectiveAnchor` persists only when `.anchored`); `HabitEditorSheet` shows an "At" `DatePicker` (hour/minute) for anchored habits.
  - **Settings**: new "Day & budget" screen (`DayBudgetSettingsView`) — day start/end, discretionary budget (`MinutesField`), custom-wind-down toggle, nudge toggle; persists + reschedules on change. Linked from Settings → Day.
  - 12 tests (`DayWindowTests` ×9, anchor sync round-trip + legacy ×2, editor anchor persist/clear ×2). 163 pass.
  - **Note**: anchored *timeline placement* (sorting the deck by anchor time / a clock-ordered view) still deferred — today anchored = a reserved block carrying a time it doesn't yet sort by.

- [x] **Phase 23 — Evening as a surfaced prompt** (build-queue #3): retired the hard 20:00 `isEvening` screen-takeover.
  - **`EveningPromptPolicy`** (pure): `shouldSurface(nowMinute:windDownMinute:resolvedCount:unresolvedCount:)` — surfaces once the clock passes the user's wind-down minute (regardless of outcome), or early when everything's resolved (≥1 resolved, 0 unresolved; vacuous-truth guarded). Interruptions excluded by the caller. 4 tests.
  - **UI**: `DailyDeckView` no longer swaps the whole screen for `EveningRitualView`. Instead a dismissible "Wind down" prompt **card** appears as the top List section when the policy fires; "Reflect" opens `EveningRitualView` in a **sheet** (now titled "Tonight" with a Done button). Brand header + floating + menu stay up all evening. `isEvening` removed.
  - **Timing**: wind-down minute comes from `DayWindowStore().current.resolvedWindDownMinute` (explicit wind-down, else day-end−60 — derived from the user's own day, not a hardcoded hour). Debug "Force evening" sets windDown=0 (always surface); "Force day" suppresses.
  - **Dismissal**: `@AppStorage` stores the start-of-day timestamp of dismissal — sticks for the day, resets next morning.
  - **Sunset note**: astronomical sunset fallback intentionally NOT built — it needs a latitude we deliberately don't collect (privacy: no GPS). The user-day-derived wind-down (end−60) satisfies "no hardcoded hour" while staying privacy-clean. Revisit only if users ask for true sunset.

- [x] **Phase 24 — Journal capture + E2EE + On-This-Day** (build-queue #4):
  - **E2EE posture (decided)**: field-level encryption of the journal *note*, owner-device only. `JournalCrypto` (CryptoKit AES-GCM): `seal(_:key:)` → `"wpx1:"`+base64 combined box; `open(_:key:)` decrypts, passes legacy *unmarked* plaintext through, returns nil on wrong-key/corruption (UI shows a "locked" placeholder, never garbage); non-deterministic (per-seal nonce). `JournalKeyStore` get-or-creates a 256-bit key in the **Keychain** (`AfterFirstUnlock`, **not** iCloud-synced, never exported). The note is sealed *before* it touches SwiftData or sync, so Supabase only ever stores ciphertext — no server/AI/provider can read it. **No migration** (ciphertext rides the existing `summary_note` text column; DTO unchanged).
  - **Capture**: `EveningRitualView.saveNote` seals via the device key; re-opening the prompt decrypts today's saved note back into the field; a "Encrypted on this device — only you can read it" lock caption added.
  - **Recap / On-This-Day**: `OnThisDaySelector.onThisDay(reference:journals:)` (pure) — same month+day in earlier years, newest first, excludes tombstones. New `MemoriesView` (`@Query` journals): "On this day" + "Recent reflections", notes decrypted on the fly, locked/empty placeholders. Reached via a "Memories" card on Profile.
  - 9 tests (`JournalCryptoTests` ×6, `OnThisDaySelectorTests` ×3). 176 pass.
  - **Trade-off documented**: lose the device key (reinstall without Keychain restore) → past notes unreadable. Surfaced, not silent. **Parked** (north-star): share-grant decryption for the sharing edge case; family/posthumous handoff; on-device journal AI (Gemma/Llama-class, zero egress).

- [x] **Phase 25 — Production hardening** (build-queue #5):
  - **DEBUG-gated dev tooling**: Settings → Data (Re-seed / Reset to habits / Run rollover) + Debug (Force evening / Force day) sections are now wrapped in `#if DEBUG` — never shipped to users. Verified Release config builds clean. "Sync now" stays (legit user action).
  - **Automated sync + rollover**: `HabitTrackerApp` observes `scenePhase`; on every foreground (when signed in) it runs the idempotent end-of-day rollover catch-up (`JournalArchiver.rollover`) + a fire-and-forget cloud sync (`AutoSync.run` — new thin wrapper, no-ops when Supabase unconfigured, swallows errors). Pairs with the existing midnight `BGAppRefresh`. Users no longer need the manual buttons.
  - No new pure logic → no new tests (wiring only; existing `JournalArchiverTests` + sync tests cover the rollover/sync paths). 176 pass.

## Known Issues (Phase 20)
- (none open from round 5) Confirming a switch flags the interrupted habit `stoppedEarly: true` — it was ended before its target by the user's choice.
- `repeatHabit`/`reopen` set `availableMinutes` budget but don't re-run compression on the clone beyond the normal load pass.

## Unified Test Pass (current state)
**B-series — re-verify this session's coded changes on-device:**
- [x] B1 Today card & header · B2 completion gates · B3 inject interruption · B4 add habit — **all signed off OK**.
- [ ] **B5 energy sync** — pending. NOTE: the "Reset to habits only + Sync now" method FAILS by design (incremental sync watermark `cursor.lastSyncAt` skips unchanged server rows; Reset wipes the DB but not the UserDefaults cursor). Correct test: inject (e.g. High/red) → Sync now → **delete the app** (wipes DB *and* cursor) → reinstall → sign in same account → first pull re-hydrates with the energy intact. (Or use a 2nd simulator.)

**A-series — core flows not yet walked through:**
- [ ] **A1** Today — drag-reorder Up next, confirm order persists across reload.
- [ ] **A2** Work tab — OKR flow (Objective → KR → Project → Milestone/ProjectTask).
- [ ] **A3** Brain dump / voice ingestion (capture → proposal → apply).
- [ ] **A4** Profile editor (view/edit, email change).

## Build Queue — Journal-vault direction ✅ ALL SHIPPED (Phases 21.1–25)
1. ~~Habit-kind editor UI + compression~~ ✅ **Phase 21.1**.
2. ~~User day-window + budget decoupling + notifications + anchored time-of-day~~ ✅ **Phase 22**.
3. ~~Evening reflection as a surfaced prompt~~ ✅ **Phase 23** (sunset fallback deliberately skipped — no GPS; see phase note).
4. ~~Journal capture + E2EE → recap / On-This-Day~~ ✅ **Phase 24**.
5. ~~Production hardening (DEBUG-gate dev controls; automate sync + rollover)~~ ✅ **Phase 25**.

**Owed follow-ups** (small, surfaced for the test pass): anchored *timeline placement* (sort/clock-ordered deck view) — stored+synced but not yet sorted by; on-device journal AI (parked, north-star); journal share-grant decryption (parked).

## Pivot — Memory-vault rewrite (Sprint 0–1, 2026-06)

> Budget engine scrapped; see [`docs/product/PRD.md`](docs/product/PRD.md) +
> [`docs/product/backlog.md`](docs/product/backlog.md).

- **Sprint 0 — teardown** ✅ (inc 1–4): removed `BudgetCalculator`, day-window /
  notifications / budget-settings + evening prompt, interruption injector,
  discipline scoring + `EveningRitualView`. Streaks rewired to `StreakCalculator`.
  150 tests green; CI green. The budget *core* deferred to S1 §1.1 (can't drop
  `DailySession`'s shape without the replacement model).
- **Sprint 1 §1.1 inc 5a — new habit model (additive)** ✅: added `HabitType`
  (checkIn/count), `HabitCategory` (health/lifestyle), `Routine` (Morning/Noon/
  Afternoon/Evening time buckets), and `HabitEntry` (one per-habit-per-day
  completion record, replaces `DailySession`). `Habit` gained type/target/
  category/routines/archivedAt; `entries` relationship; repo gained entry
  CRUD; `HabitStreak` computes per-habit daily streaks (any missed day breaks).
  Added **alongside** budget fields so nothing breaks yet. **163 tests green**
  (13 new). Harness-first: `HabitEntryTests` + `HabitStreakTests` written red
  first. Next: 5b Today screen → 5c sync/widget/intent cutover → 5d teardown +
  store reset.
- **Process — UI/UX made a first-class phase** (2026-06-28): wired the **Figma
  Dev Mode MCP** (`figma`, local config, read-only — designs originate in Figma,
  Claude reads/implements). New [`docs/process/design-workflow.md`](docs/process/design-workflow.md)
  defines the E2E pipeline (Requirements → Figma → review → `ui-spec.md` → build
  harness-first → visual QA). Added `docs/product/ui-spec.md`; **design-before-
  build gate** added to DoR/DoD (`scrum.md`); backlog now splits every screen
  into a design item + build item (EPIC-UI + `x.0` rows); ADR-007 records it;
  `CLAUDE.md` updated. No code change — planning/process only.

## Backlog / Ops
- **AI habit-budget workflow (parked, big feature)**: Habits are streak items (did/didn't), not tasks — don't auto-defer (deferral/"Bumped" already removed in Phase 20.1). Leave the compression engine in `BudgetRecalculator` (the "(was XX)" shrink) AS-IS until this lands. Plan: (1) habit-config screen lets durations exceed budget (no blocking); user duration becomes the "(was XX)" bracket. (2) live "remaining budget" signal while editing. (3) post-config AI pass scans for over-budget and proposes a full revised duration list via interactive wizard — suggested value shown before the bracket, reusing the "XX (was YY)" display. (4) per-habit approve / keep-as-is before landing in Up next. (5) likely a post-onboarding tutorial + master habit-config input feeding Today. Discuss before building.
- Manual: update Magic Link email template at `https://supabase.com/dashboard/project/<project-ref>/auth/templates` to use `{{ .Token }}`.
- Periodic local tombstone prune (rows where `deletedAt < now - 30d`).
- Live Activities 8-hour timeout recovery flow.
