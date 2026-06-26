# Spec: Discipline Score

**Status**: Draft for review
**Phase**: v3 / 14

## What it solves
Habit apps shame users with overdue red badges; v3 inverts this. **Discipline = "did you do the version of today that today actually allowed?"** Compression-aware. Anti-guilt.

## Per-session score

For each `DailySession` (excluding interruptions):

```
if status == .completed:
    if actualMinutes >= compressedMinutes:    1.0   # full credit
    elif actualMinutes >= compressedMinutes * 0.7: 0.7   # partial
    else:                                      0.5   # showed up

if status == .pending and end-of-day reached:  0.0   # skipped
if status == .deferred (bumped by compression): excluded  # not your fault
if status == .active at end-of-day:            0.5   # in-progress credit
```

Rationale:
- Treating "compressed completion" as 100% is the key anti-guilt move.
- "Showed up but bailed" still earns 0.5 — better than punishing partial effort.
- Deferred-by-compression doesn't count against you. The system bumped it, not you.

## Daily aggregate

```
score_day = sum(session.score * session.weight) / sum(session.weight)
```

Where `session.weight` ladder:
- `.high` energy session = 3
- `.mid` energy session = 2
- `.low` energy session = 1

So skipping one deep-work block hurts more than skipping a 5-min stretch. Maps naturally to v3's "Discipline over Volume" — quality-weighted, not count-weighted.

Daily score is `0.0…1.0`, shown as percentage in the Evening Ritual ring.

## Streak interaction

A "streak day" requires `score_day >= 0.6`. Threshold rationale:
- Doing all your high-energy work but skipping low-energy fluff still scores ~0.75 → streak survives.
- Doing only fluff while skipping deep work scores ~0.25 → streak breaks. Forces honest priorities.

Threshold is a constant; expose in Settings later if needed.

### Grace
- Days with **zero pending sessions** (e.g., scheduled rest day, midnight rollover put nothing on deck) are **excluded** from the streak — they neither break nor extend it.
- This prevents "I had no habits today so I lost my streak" frustration.

## What gets surfaced where

| Surface | Number shown |
|---|---|
| Profile tab stat card "Day streak" | Current consecutive `score >= 0.6` days (with grace) |
| Profile tab stat card "Discipline" | Today's `score_day` as % |
| Evening Ritual (post-8 PM Today screen) | Big ring filled to `score_day`, plus per-session breakdown |
| Reports tab (existing) | Replace "Total time" headline with "Avg discipline" (week/month) |

## Operational rules

- Discipline is **derived**, never stored as ground truth. Compute from sessions + their statuses. Allows backfill when scoring rules change.
- Recomputed on every Today/Profile load; cached for the current day in-memory in `ProfileViewModel`.
- Server-side: the existing `progress-report` Edge Function gets a new field `avg_discipline` computed the same way over the window.

## Out of scope
- Negative scoring for over-commitment (planning too much). v3 explicitly avoids this guilt vector.
- Weekly/monthly score *trends* with graphs. Reports tab shows just the average for now.

## Open questions
1. **0.5 for "showed up but bailed" vs 0.3?** Recommend 0.5 — generous on purpose. The anti-guilt thesis says "any presence is more discipline than zero."
2. **Should `.compressed`-status sessions be tagged as such in UI history?** Recommend: yes, small "compressed" badge on session detail. User should *see* the system flexing for them.
3. **Score for an Interruption that was completed?** Recommend: doesn't contribute. Interruptions track *reality*, not *discipline*.
