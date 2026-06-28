# Product Backlog

Single ordered backlog for the **memory-vault MVP**. Derived from
[`PRD.md`](PRD.md); managed per [`../process/scrum.md`](../process/scrum.md).
Shipped history → [`../../implementation-plan.md`](../../implementation-plan.md).

Status: 🔵 ready · 🟡 needs refinement · ✅ done · ⛔ blocked
Size: S (≈½ day) · M (1–2 days) · L (3+ days)

> The old budget-era backlog was replaced wholesale on the 2026-06 pivot. Budget
> engine is being **scrapped**, not extended.

---

## EPIC-0 — Foundation & teardown  *(Sprint 0)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 0.1 | Initialize git + baseline commit | S | ✅ |
| 0.2 | Stand up CI (GitHub Actions) running `make test`; repo public | M | ✅ |
| 0.3 | **Remove the budget engine** — peripheral machinery (day-window/notifications/budget-settings, interruption injector, discipline scoring, evening prompt/ritual) removed across inc 1–4, all green. The **core** (`BudgetRecalculator`, `DailySession` budget shape, budget card/“min to go”, `HabitKind`/anchored, `MinutesField`/`MinutesInput`, compression) **folds into Sprint 1 §1.1** — it can't be deleted without the replacement model. | L | 🟡 core → S1 |
| 0.4 | Wire the QC stack (XCTest keep + Maestro smoke harness) per QC doc | M | 🔵 owed |

> **Design-before-build convention (all UI work).** Every user-facing story is
> split into a **UX design** item (Figma frames + flow decisions, benchmarked
> against TickTick/Habitify/Things3 — output: signed-off frame + open forks
> resolved) and a **build** item. A build item is not `🔵 ready` until its design
> item is `✅`. Pipeline: [`../process/design-workflow.md`](../process/design-workflow.md).
> Screen spec → [`ui-spec.md`](ui-spec.md); hard-to-reverse calls →
> [`../architecture/decisions.md`](../architecture/decisions.md). The `D` rows
> below (UI.0 / x.0) are the design items; this convention applies to **every**
> epic with screens, including the Sprint 2–3 epics whose design items are added
> as they enter a sprint.

## EPIC-UI — App shell & design system  *(Sprint 1, foundational)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| UI.0 | **Design pass (Figma)**: app-shell layout + design-system sheet (color/type/spacing tokens light+dark, components: habit row, check control, count stepper, routine header, empty/error/loading states). Sign-off → `ui-spec.md` + token table. | M | 🔵 |
| UI.1 | App shell & navigation: tab structure (Today · Diary · Stats · Profile) + root routing; replace the budget-era `DailyDeckView` entry point. | M | 🔵 |
| UI.2 | Design tokens: color / type / spacing scale, light+dark; the substrate EPIC-6 theming plugs into. | M | 🔵 |
| UI.3 | Reusable components: habit row, check-off control, count stepper, routine section header, empty/rest-state. | M | 🔵 |
| UI.4 | Loading / empty / error state conventions across screens. | S | 🔵 |

## EPIC-1 — Habits & Routines (core loop)  *(Sprint 1)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 1.1 | `Habit` model reshape: `type` (check-in \| count), `category` (health \| lifestyle), `routines: [Routine]`, optional location. Drop budget fields. **inc 5a done** (model + `HabitEntry` + repo added *additively*, 163 green); budget-field drop + store reset → inc 5d. | M | 🟡 5a✅ |
| 1.2 | `Routine` = time-of-day bucket (Morning/Noon/Afternoon/Evening); a habit can be in 1+. **Done** (`Routine` enum, inc 5a). | S | ✅ |
| 1.3 | **Today screen — UX design**: routine-grouped layout, check-off vs count-stepper rows, ordering, empty/all-done state. Output: sketch + forks resolved. *(← the decision I jumped ahead on.)* | S | 🔵 |
| 1.4 | **Today screen — build**: `TodayViewModel` + view over `HabitEntry`, grouped by routine, lazy entry creation on first interaction (inc 5b). | M | 🔵 |
| 1.5 | **Add/Edit habit — UX design**: add-button placement, form fields (title/type/target/category/routines/reminder), validation; benchmark competitors' add-flow. | S | 🔵 |
| 1.6 | **Add/Edit/Archive habit — build**: form + `HabitEditorViewModel` reshape. | M | 🔵 |
| 1.7 | Streaks + completion % per habit — surfaced in Today + habit detail (logic = `HabitStreak`, done 5a; this is the surfacing). | M | 🔵 |
| 1.8 | Reminders / notifications per habit. | M | 🔵 |

**Acceptance (epic):** create a habit, see it under the right routine, check it off, watch the streak grow; survives relaunch.

## EPIC-2 — Mood  *(Sprint 2)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 2.0 | **Design pass (Figma)**: mood-capture UI (5-pt picker + note), where it surfaces after a routine. → `ui-spec.md`. | S | 🟡 |
| 2.1 | `Mood` model: 5-pt scale (Euphoric>Happy>Neutral>Sad>Horrible). | S | 🔵 |
| 2.2 | Capture mood after a routine is completed + optional note. | M | 🔵 |
| 2.3 | Surface mood in end-of-day flow + stats. | S | 🟡 |

## EPIC-3 — Private diary (E2EE + Face ID)  *(Sprint 2)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 3.0 | **Design pass (Figma)**: diary list + entry composer + Face ID lock screen + attachment UI. → `ui-spec.md`. | M | 🟡 |
| 3.1 | Reuse `JournalCrypto`/`JournalKeyStore`; confirm AES-GCM + Secure-Enclave key. | S | 🔵 |
| 3.2 | **Face ID / PIN gate** (LocalAuthentication) to open the diary. | M | 🔵 |
| 3.3 | Diary entry composer with image attachments (encrypted at rest). | L | 🟡 |

## EPIC-4 — On-this-day & Memories  *(Sprint 3)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 4.0 | **Design pass (Figma)**: memory rewind UI (on-this-day card, memory browse). → `ui-spec.md`. | S | 🟡 |
| 4.1 | Reuse `OnThisDaySelector` + `MemoriesView`; rewind by creation date / first achievement / memory. | M | 🔵 |

## EPIC-5 — Statistics  *(Sprint 3)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 5.0 | **Design pass (Figma)**: stats screens (habit performance + mood; day/week/month/year), chart styles. → `ui-spec.md`. | M | 🟡 |
| 5.1 | Native (not web-view) stats: habit performance + mood, daily/weekly/monthly/yearly. | L | 🔵 |

## EPIC-6 — Theme switcher  *(Sprint 3)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 6.0 | **Design pass (Figma)**: theme picker UI (stock themes, local photo, light/dark) over UI.2 tokens. → `ui-spec.md`. | S | 🟡 |
| 6.1 | Reuse background/theme system: stock themes + local photos + light/dark. | M | 🔵 |

## EPIC-7 — On-device recall plumbing (MVP foundation for V1 AI)  *(Sprint 3, stretch)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 7.1 | Embed diary entries on-device (Apple `NaturalLanguage`); store vectors in `sqlite-vec`; local-only. | L | 🟡 |
| 7.2 | Semantic search over entries (no LLM yet) powering recall. | M | 🟡 |

---

## Later (post-MVP — from PRD tiers, not yet refined)
- **V1:** Projects/Goals (OKR, reuse models) · Widgets · **on-device LLM assistant** (MLX, over EPIC-7 plumbing) · **cloud sync** (premium; diary ciphertext-only; cross-device key via iCloud Keychain).
- **V2:** Friends/social + tiered sharing (envelope encryption) · 3rd-party integrations · white noise · countdown · quote-of-day · **lock-in mode** (Screen Time / FamilyControls) · **Android** (native Compose).

## Open decisions (mirror of PRD log)
- [x] Platform — native iOS-first, Android fast-follow.
- [x] Diary — E2EE + Face ID.
- [x] MVP single-device (sync = V1) — confirmed.
