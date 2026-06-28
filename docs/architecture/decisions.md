# Architecture Decision Records (ADRs)

One entry per hard, hard-to-reverse decision. Newest at the bottom.

---

## ADR-001 — Additive, backward-compatible migrations + multi-tenant RLS
**Date** 2026-06-15 · **Status** Accepted
**Context** Pre-PMF "schema changes are free" is retired; we're commercializing (aim $1M MRR) with real users' data on Supabase.
**Decision** All migrations are additive (`add column if not exists … default` / nullable). DTOs decode legacy rows tolerantly (`decodeIfPresent ?? default`). Every table is per-user via RLS (`user_id default auth.uid()`). No destructive migrations, no silent data loss.
**Consequences** Slightly more DTO boilerplate (custom `init(from:)`). Old client versions keep working against new columns. Forever-additive means periodic cleanup debt (see ADR follow-ups / tombstone prune).

## ADR-002 — Journal E2EE: device-Keychain key, ciphertext at rest
**Date** 2026-06-17 · **Status** Accepted (awaiting user confirm — see backlog D-E2EE)
**Context** The journal is the product's moat — a private memory vault. Requirement: owner-only, no server/AI/provider can ever read it.
**Decision** Field-level AES-GCM (CryptoKit) on `Journal.summaryNote`. 256-bit key lives in the **Keychain only** (`AfterFirstUnlock`, not iCloud-synced, never exported). Note is sealed before it reaches SwiftData or sync, so Supabase only stores ciphertext.
**Consequences** True E2EE with no server-held key. **Trade-off**: losing the device key (reinstall without Keychain restore) makes past notes permanently unreadable — surfaced to the user as "locked", never lost silently. Alternative (iCloud Keychain sync for recoverability) is parked as L6 if the user prefers recoverability over strict on-device-only.

## ADR-003 — No GPS; wind-down defaults to day-end − 60, not astronomical sunset
**Date** 2026-06-17 · **Status** Accepted
**Context** Spec said evening timing = "user wind-down wins, else local sunset." True sunset needs a latitude; we deliberately don't collect location (privacy-consistent with the vault positioning).
**Decision** Wind-down = explicit user time, else `dayEnd − 60min` (derived from the user's own day). No hardcoded hour, no sunset math, no location.
**Consequences** Satisfies "no hardcoded hour" while staying location-free. True sunset is conditional/parked (X3/backlog) — only if users ask, and only via opt-in coarse location or a city picker.

## ADR-004 — Habits are streak items; they never defer
**Date** 2026-06 · **Status** Accepted
**Context** TickTick/Things 3/Habitica don't bump habits to tomorrow. A habit is did/didn't, not a task.
**Decision** Compression shrinks over-scheduled days to the floor and runs over; it never produces `.deferred`. `SessionStatus.deferred` is kept (vestigial, always 0) to avoid churn.
**Consequences** No "Bumped" UI. The compression "(was XX)" shrink stays for the future AI habit-budget flow (L5).

## ADR-005 — Sync scope: Habits/Sessions/Journals only; OKR graph local-only
**Date** 2026-06 · **Status** Accepted
**Context** The v3 OKR rewrite (Objective→KR→Project→{Milestone,Task}) is the planning layer; the daily loop is habits+sessions+journals.
**Decision** Only Habits, Sessions, Journals have DTOs/RLS tables and sync. The OKR graph is local SwiftData for now.
**Consequences** Smaller sync surface, faster iteration on planning UI. Cross-device OKR sync is a future addition (additive per ADR-001).

## ADR-006 — Budget ≠ waking hours (decoupled explicit input)
**Date** 2026-06-16 · **Status** Accepted
**Context** A day window (start/end) is *not* a habit budget. The 9-5 / sleep / meals are fixed blocks subtracted from the day, not things you "budget."
**Decision** `discretionary budget = window − fixed blocks − ~0 moment-habits`, but it stays an **explicit user input** (default 120; AI may default it later). Never auto-equate budget to window length. Habit-kind is the structural prerequisite (duration consumes, moment≈0, anchored=fixed block).
**Consequences** `DayWindow.budgetMinutes` is separate from `lengthMinutes`. The day window drives nudges + anchors, not the budget number.

## ADR-007 — Design-before-build with Figma as the visual source of truth
**Date** 2026-06-28 · **Status** Accepted
**Context** UI/UX was not a tracked phase — screens were smuggled into logic stories, leading to building Today off an un-reviewed layout. Commercializing means UI quality is a feature, not an afterthought.
**Decision** Every user-facing story splits into a **UX-design item** (Figma frame + flow, signed off) and a **build item**; the build item is not DoR-ready until the design is `✅` and its `ui-spec.md` section exists. Figma is the **visual source of truth**; `ui-spec.md` is the code-facing translation. Figma↔Claude handoff is the **Dev Mode MCP** (`http://127.0.0.1:3845/mcp`), which is **read-only** — Claude reads existing frames and implements SwiftUI to match; it never authors Figma files. Pipeline: `docs/process/design-workflow.md`.
**Consequences** Slower start per screen (design gate) but far less rework and a coherent design system. Designs must originate in Figma (Minh / Figma "First Draft"); the MCP cannot create them. Design tokens live in Figma variables **and** a Swift `DesignTokens` mirror — drift risk if not kept in sync.
