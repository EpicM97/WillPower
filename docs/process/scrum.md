# Process — SDLC + Scrum (adapted for solo founder + AI pair)

> Honest framing: classic Scrum assumes a team. Here the "team" is **you (Minh)**
> + **Claude** as an AI pair. So we keep Scrum's *spine* (sprints, a single
> ordered backlog, a Definition of Done, a review/retro rhythm) and drop the
> ceremony theatre that only makes sense for multiple humans.

## Roles
| Scrum role | Here |
|---|---|
| Product Owner | **Minh** — owns vision, priorities, accepts/rejects increments |
| Developers | **Minh + Claude** — design, build, test |
| Scrum Master | Lightweight/shared — whoever spots a process smell raises it |

## SDLC phases → where they live
| SDLC phase | Artifact / home |
|---|---|
| Requirements | `product/PRD.md` (vision, MOAT, feature tiers) |
| **UX design** | **Figma** (flows, hi-fi screens, design system) → code-facing spec in `product/ui-spec.md`; pipeline in `process/design-workflow.md` |
| Architecture | `architecture/architecture-proposal.md`, `architecture/tech-spec.md`, ADRs in `architecture/decisions.md` |
| Build | Sprints (this doc) → `Sources/`, harness-first |
| Test / QC | `process/qa-test-automation.md` + `Tests/` |
| Deploy | TestFlight → App Store (CI runs `make test`) |
| Maintain | `implementation-plan.md` changelog + backlog |

> **One pipeline, E2E.** Requirements → **UX design (Figma) → review/sign-off →
> spec (ui-spec.md)** → build (harness-first) → QC → review → deploy. See
> [`design-workflow.md`](design-workflow.md). UI/UX is a phase, not an afterthought.

## Cadence
- **1-week sprints.** Short, because a founder+AI pair ships fast and priorities move; lengthen later if planning overhead feels wasteful.
- **Sprint Planning** (sprint start): pull the top of `product/backlog.md` into a Sprint Backlog; write a one-line **Sprint Goal**. For user-facing work, the **UX-design item is pulled first** so its Figma frame is signed off before the build item starts (design-before-build).
- **Daily** = async self-check (no standup-with-yourself): "shipped / next / blocked." Claude logs progress in the changelog.
- **Sprint Review** (sprint end): demo the increment **on-device**; PO (Minh) accepts stories against acceptance criteria; update PRD/backlog.
- **Retro** (sprint end, 5 min): one thing to keep, one to change.

## Estimation
Simple **S / M / L** (≈ ½ day / 1–2 days / 3+ days). No story points; the precision isn't worth it at this size.

## Definition of Ready (DoR) — a story may enter a sprint only if
- It has a clear **user-facing outcome** and **acceptance criteria**.
- Dependencies are known and unblocked.
- It's **testable** (we can name the unit/UI test that proves it).
- It's sized S/M/L and fits the sprint.
- **Design-before-build gate** (UI build stories only): the matching **UX-design
  item is `✅`** — Figma frame signed off **and** its `ui-spec.md` section written.

## Definition of Done (DoD) — a story is done only when
- **Harness-first** tests written *before* the logic, and **all tests green** (`make test`).
- Builds clean in **Debug *and* Release**.
- User-facing flows have at least a **smoke UI test** (see QC doc).
- **Matches the approved Figma design**; **light + dark**; **accessibility pass**
  (Dynamic Type, VoiceOver labels, ≥44pt targets, ≥AA contrast) per
  [`design-workflow.md`](design-workflow.md).
- **Docs updated**: PRD/backlog status, `implementation-plan.md` changelog entry, `ui-spec.md`/tech-spec if design changed.
- **Committed to git** with a clear message; no secrets.
- **On-device sanity check** done (it actually works, not just compiles).

## Sprint plan (tentative — PO confirms each planning)

> Every sprint with new screens opens with a short **design pass** (Figma frames
> + `ui-spec.md` sections, signed off) before its build stories go ready.

### Sprint 0 — Foundation & teardown ✅
**Goal:** clean ground for the MVP. ✅ git · CI · budget engine torn down (inc 1–4) · new habit model added (`HabitEntry`/`Routine`, inc 5a) · QC stack chosen (XCTest live; Maestro smoke owed). Budget *core* removal → S1 (inc 5d).

### Sprint 1 — Habits & Routines (the core loop) *(current)*
**Goal:** a user can create simple habits, see them grouped by routine (time-of-day), and check them off with streaks — on a real design system.
- **Design pass:** EPIC-UI shell + Today + Add/Edit frames in Figma → `ui-spec.md` (stories UI.1, 1.3, 1.5).
- **Build:** design system + shell (EPIC-UI), Today screen over `HabitEntry` (5b/1.4), Add/Edit habit (1.6), streak surfacing (1.7), reminders (1.8).
- **Cutover/teardown:** sync/widget/intent → `HabitEntry` (5c); delete `DailySession`/budget core + store reset (5d).

### Sprint 2 — Mood + Diary
**Goal:** mood capture after a routine; E2EE diary unlocked by Face ID. *(Opens with a Mood + Diary design pass.)*

### Sprint 3 — Recall + Stats + Theme
**Goal:** On-This-Day, statistics, theme switcher → MVP feature-complete, ready for TestFlight. *(Opens with a Stats + Theme design pass.)*

*(V1/V2 sprints planned after MVP ships — see backlog.)*
