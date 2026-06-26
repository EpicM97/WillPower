# Product Backlog

Forward-looking only. Shipped history lives in
[`implementation-plan.md`](../../implementation-plan.md). Strategic framing:
WillPower is an **emotional memory vault**, commercializing toward $1M MRR →
additive migrations, multi-tenant RLS, no silent data loss.

Status legend: 🟡 awaiting verification · 🔵 ready to build · ⚪ parked · 🟢 done-pending-signoff

---

## NOW — in your test pass (Phases 22–25, code complete, 176 tests green)
These shipped this session and await your on-device sign-off (see
[test-plan.md](test-plan.md)).

| ID | Item | Status |
|----|------|--------|
| N1 | Day & budget settings — window start/end, decoupled budget, wind-down, nudges | 🟢 |
| N2 | Anchored habits carry a clock time (editor time picker, synced) | 🟢 |
| N3 | Evening = dismissible "Wind down" prompt (8 PM takeover retired) | 🟢 |
| N4 | Journal notes E2EE (Keychain key, ciphertext at rest + in sync) | 🟢 |
| N5 | Memories surface (On-This-Day + recent reflections) | 🟢 |
| N6 | Prod hardening — DEBUG-gated dev tools; auto sync + rollover on foreground | 🟢 |

**Two decisions made on your behalf while you were away — confirm or veto:**
- **D-E2EE:** journal key is device-Keychain-only (no iCloud). Reinstall without a Keychain restore ⇒ past notes unreadable (shown as "locked", never lost-silently). Veto → switch to iCloud Keychain sync for recoverability. See [ADR-002](../architecture/decisions.md).
- **D-Sunset:** "wind-down else sunset" → sunset **not** built (needs latitude we won't collect; no GPS). Wind-down defaults to *day-end − 60 min*. See [ADR-003](../architecture/decisions.md).

---

## NEXT — small, owed follow-ups
| ID | Item | Notes |
|----|------|-------|
| X1 | **Anchored timeline placement** | Anchored habits store/sync `anchorMinuteOfDay` but the deck doesn't yet *sort* by it. Build a clock-ordered view or interleave anchors into Up-next by time. 🔵 |
| X2 | Budget live-refresh while app open | Budget is read on `.task` + tab re-show; editing it in another tab updates on return, not instantly. Acceptable now; revisit if it feels stale. 🔵 |
| X3 | True sunset wind-down (conditional) | Only if users ask. Would need an opt-in coarse-location or city picker. ⚪ |

---

## LATER — parked (north-star; do not build until core loop retains)
| ID | Item | Notes |
|----|------|-------|
| L1 | **On-device journal AI** | Gemma/Llama-class (MLX/Core ML/llama.cpp), **zero network egress**. Correlate felt(journal) × did(habits): pattern surfacing, semantic recall, mood inference, year-in-review. No provider API for journal data — ever. ⚪ |
| L2 | Journal **share-grant** decryption | Owner can grant specific people read access. The only sanctioned decrypt path beyond the owner. ⚪ |
| L3 | Family-sharing + posthumous handoff | The vault's emotional moat narrative. ⚪ |
| L4 | Opt-in **server** journal AI | Clearly-labeled future toggle, never default. ⚪ |
| L5 | **AI habit-budget workflow** | Big feature. Durations may exceed budget (no blocking); user duration → "(was XX)" bracket; live remaining-budget signal while editing; post-config AI pass proposes a revised duration list via wizard; per-habit approve. Leave the compression engine as-is until this lands. Discuss before building. ⚪ |
| L6 | iCloud-Keychain journal-key recoverability | Trade some privacy for "don't lose notes on reinstall." Only if D-E2EE is vetoed. ⚪ |

---

## OPEN QA — flows not yet walked through (see test-plan.md)
| ID | Flow | Status |
|----|------|--------|
| B5 | Energy/kind sync round-trip (delete-app → reinstall → re-pull) | 🟡 |
| A1 | Today — drag-reorder Up next persists across reload | 🟡 |
| A2 | Work tab — OKR flow (Objective → KR → Project → Milestone/Task) | 🟡 |
| A3 | Brain dump / voice ingestion (capture → proposal → apply) | 🟡 |
| A4 | Profile editor (view/edit, email change) | 🟡 |

---

## OPS / CHORES
| ID | Item | Notes |
|----|------|-------|
| O1 | Magic-link email template | Set to `{{ .Token }}` in Supabase dashboard. User action. |
| O2 | Stock background images | Drop curated Unsplash images into `supabase/storage/backgrounds/stock/`, run `make backgrounds-upload`. User action. |
| O3 | Tombstone prune | Periodically delete local rows where `deletedAt < now − 30d`. |
| O4 | Live Activity 8-hour timeout recovery | Long-running habits exceed the LA cap. |
| O5 | `GEMINI_API_KEY` secret | `make supabase-secret-set NAME=GEMINI_API_KEY VALUE=…` for brain-dump LLM. User action. |
