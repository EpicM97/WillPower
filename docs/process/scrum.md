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
| Design | `architecture/architecture-proposal.md`, `architecture/tech-spec.md`, ADRs in `architecture/decisions.md` |
| Build | Sprints (this doc) → `Sources/`, harness-first |
| Test / QC | `process/qa-test-automation.md` + `Tests/` |
| Deploy | TestFlight → App Store (CI runs `make test`) |
| Maintain | `implementation-plan.md` changelog + backlog |

## Cadence
- **1-week sprints.** Short, because a founder+AI pair ships fast and priorities move; lengthen later if planning overhead feels wasteful.
- **Sprint Planning** (sprint start): pull the top of `product/backlog.md` into a Sprint Backlog; write a one-line **Sprint Goal**.
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

## Definition of Done (DoD) — a story is done only when
- **Harness-first** tests written *before* the logic, and **all tests green** (`make test`).
- Builds clean in **Debug *and* Release**.
- User-facing flows have at least a **smoke UI test** (see QC doc).
- **Docs updated**: PRD/backlog status, `implementation-plan.md` changelog entry, tech-spec if design changed.
- **Committed to git** with a clear message; no secrets.
- **On-device sanity check** done (it actually works, not just compiles).

## Sprint plan (tentative — PO confirms each planning)

### Sprint 0 — Foundation & teardown *(current)*
**Goal:** clean ground for the MVP. ✅ git initialized · set up CI · **remove the budget engine** · reshape `Habit` → type/category/routine · pick + wire the QC stack.

### Sprint 1 — Habits & Routines (the core loop)
**Goal:** a user can create simple habits, see them grouped by routine (time-of-day), and check them off with streaks.

### Sprint 2 — Mood + Diary
**Goal:** mood capture after a routine; E2EE diary unlocked by Face ID.

### Sprint 3 — Recall + Stats + Theme
**Goal:** On-This-Day, statistics, theme switcher → MVP feature-complete, ready for TestFlight.

*(V1/V2 sprints planned after MVP ships — see backlog.)*
