# Manual Test Plan

Automated coverage is 176 XCTests (`make test`). This plan covers what needs a
human on-device. Track status in [backlog.md](backlog.md) (NOW / OPEN QA).

## This session's changes (Phases 22–25) — verify on-device
| # | Step | Expected |
|---|------|----------|
| T1 | Profile → ⚙️ → **Day & budget**; set budget ≠ 120, set a day end | Back on Today, the budget card reflects the new number |
| T2 | Add habit → **Anchored** kind | A "Time" picker appears; save, reopen → time persisted |
| T3 | Settings → Debug → **Force evening** | A dismissible "Wind down" card appears atop the deck (no screen takeover) |
| T4 | Tap **Reflect**, write a note, Save; reopen the prompt | Note returns decrypted into the field; "Encrypted on this device" caption visible |
| T5 | Profile → **Memories** | Your reflection appears under "Recent reflections" |
| T6 | Day & budget → toggle **nudges** on | iOS prompts for notification permission |
| T7 | Dismiss the wind-down card (×) | Stays dismissed for the day; returns next day |

## B-series — prior coded-change regressions
- [x] B1 Today card & header · B2 completion gates · B3 inject interruption · B4 add habit — **signed off**.
- [ ] **B5 energy/kind sync** — inject (e.g. High/red) → Sync now → **delete the app** (wipes DB *and* the watermark cursor) → reinstall → sign in same account → first pull re-hydrates with energy/kind intact. ⚠️ "Reset to habits only + Sync now" does **not** test this — the incremental cursor skips unchanged server rows by design.

## A-series — core flows not yet walked
- [ ] **A1** Today — drag-reorder Up next; confirm order persists across reload.
- [ ] **A2** Work tab — OKR flow: Objective → KeyResult → Project → Milestone/ProjectTask.
- [ ] **A3** Brain dump / voice ingestion: capture → proposal → apply. (Needs `GEMINI_API_KEY`, ops O5.)
- [ ] **A4** Profile editor: view/edit display name, email change.

## Notes
- Sim "Busy/preflight" on first run is a known flake — `xcrun simctl shutdown all` and rerun.
- Force-evening/day toggles are **DEBUG-only** now; they won't appear in a Release build.
