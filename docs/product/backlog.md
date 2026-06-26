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
| 0.3 | **Remove the budget engine** — `BudgetRecalculator`, `DayWindow` budget, `HabitKind`/anchored, interruption injector, `MinutesField`/`MinutesInput`, compression, discipline-as-budget, the budget card/“min to go” UI. Keep tests green. | L | 🟡 in progress |
| 0.4 | Wire the QC stack (XCTest keep + Maestro smoke harness) per QC doc | M | 🔵 |

## EPIC-1 — Habits & Routines (core loop)  *(Sprint 1)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 1.1 | `Habit` model reshape: `type` (check-in \| count), `category` (health \| lifestyle), `routines: [Routine]`, optional location. Drop budget fields. | M | 🔵 |
| 1.2 | `Routine` = time-of-day bucket (Morning/Noon/Afternoon/Evening); a habit can be in 1+. | S | 🔵 |
| 1.3 | Today screen: habits grouped by routine bucket; check-off + count increment. | M | 🔵 |
| 1.4 | Streaks + completion % per habit. | M | 🔵 |
| 1.5 | Reminders/notifications per habit. | M | 🔵 |
| 1.6 | Add/edit/archive habit (clean add-flow; learn from competitors' add-button placement). | M | 🔵 |

**Acceptance (epic):** create a habit, see it under the right routine, check it off, watch the streak grow; survives relaunch.

## EPIC-2 — Mood  *(Sprint 2)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 2.1 | `Mood` model: 5-pt scale (Euphoric>Happy>Neutral>Sad>Horrible). | S | 🔵 |
| 2.2 | Capture mood after a routine is completed + optional note. | M | 🔵 |
| 2.3 | Surface mood in end-of-day flow + stats. | S | 🟡 |

## EPIC-3 — Private diary (E2EE + Face ID)  *(Sprint 2)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 3.1 | Reuse `JournalCrypto`/`JournalKeyStore`; confirm AES-GCM + Secure-Enclave key. | S | 🔵 |
| 3.2 | **Face ID / PIN gate** (LocalAuthentication) to open the diary. | M | 🔵 |
| 3.3 | Diary entry composer with image attachments (encrypted at rest). | L | 🟡 |

## EPIC-4 — On-this-day & Memories  *(Sprint 3)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 4.1 | Reuse `OnThisDaySelector` + `MemoriesView`; rewind by creation date / first achievement / memory. | M | 🔵 |

## EPIC-5 — Statistics  *(Sprint 3)*
| ID | Story | Size | Status |
|----|-------|------|--------|
| 5.1 | Native (not web-view) stats: habit performance + mood, daily/weekly/monthly/yearly. | L | 🔵 |

## EPIC-6 — Theme switcher  *(Sprint 3)*
| ID | Story | Size | Status |
|----|-------|------|--------|
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
