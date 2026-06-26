# Spec: Elastic Time Compression

**Status**: Draft for review
**Phase**: v3 / 12

## What it solves
When interruptions consume part of the user's day-budget, habits don't go "overdue" or accumulate red badges. Instead, their target durations shrink to fit the remaining time. Discipline = completing the compressed version.

## Domain

- `DailySession` (today's instance of a habit) has `baseMinutes` (target as planned) and `compressedMinutes` (current target after redistribution). Both default equal.
- `Interruption` is a one-shot `DailySession` with `isInterruption: true` and `expectedMinutes` set by the user when injecting.
- Daily budget cap = `Profile.dailyBudgetMinutes` (today's `availableMinutes`).

## Trigger
Compression runs **once per state change** that affects remaining time:
1. User injects an `Interruption` via the floating + button.
2. User marks a session `completed` with `actualMinutes != compressedMinutes` (over- or under-run).
3. User edits the day's budget cap.

It does **not** run continuously / on a timer.

## Algorithm (default: `.shrinkAll` proportional)

```
remaining_budget = daily_cap
                  - sum(completed sessions' actualMinutes)
                  - sum(active session's elapsedMinutes)
                  - sum(injected interruptions' expectedMinutes)

pending = sessions where status == .pending
target_total = sum(pending.baseMinutes)

if remaining_budget >= target_total:
    pending.compressedMinutes = pending.baseMinutes        # restore
else if remaining_budget <= 0:
    pending.compressedMinutes = floor(p)                    # everyone at floor
else:
    scale = remaining_budget / target_total
    for p in pending:
        p.compressedMinutes = max(floor(p), round(p.baseMinutes * scale))
```

### Floor
```
floor(habit) = max(5, ceil(habit.baseMinutes * 0.30))
```
- Hard minimum: 5 minutes. Below that the session is "presence", not work.
- Soft minimum: 30% of base. A 60-min deep-work block won't compress below 18 min.

### Edge cases

| Case | Behavior |
|---|---|
| Sum of floors > remaining_budget | Drop lowest-priority pending sessions one at a time until sum-of-floors ≤ remaining. Dropped sessions move to `status: .deferred`. UI shows them in a "Bumped to tomorrow" footer. |
| Interruption > remaining_budget | Accept anyway — interruptions are reality. Compression then drops sessions to floor + bumps. |
| Mid-session compression | Active session is untouched (locked to whatever target it had at start). New compression only affects `.pending`. |
| User completes early (actual < compressed) | Surplus minutes redistribute back to remaining pending via the same algorithm — they can grow back up to `baseMinutes`. |
| User runs long (actual > compressed) | Overrun is taken from remaining budget. Other pending sessions compress further. |
| All pending at floor and still over | Defer lowest-priority first (deterministic by `Habit.priority` desc, then `order` asc). |

### Strategy variants (post-MVP)
- `.dropLowest` — instead of shrinking everyone proportionally, drop low-priority sessions whole until the rest fit at `baseMinutes`. Cleaner for "I have 3 things that matter today" users.
- User-selectable in Settings; default `.shrinkAll`.

## UX

- Compression triggers an animated re-render of the Today/Focus deck: durations smoothly decrease, dropped cards slide into a "Bumped" footer with an "Undo" affordance for 5s.
- Each compressed card shows `"15 min (was 30)"` until completed.
- Discipline score (separate spec) treats `completed with actual ≥ compressedMinutes` as 100%.

## Out of scope (this spec)
- Cross-day compression (debt). v3's "Midnight Hard Reset" means each day is independent.
- Compression of `Interruption` itself (interruptions are fixed; only habits compress around them).

## Open questions
1. **Should `Interruption.expectedMinutes` be required at injection, or default to a value?** Recommend: required, with a smart default (15 min) and quick presets (15 / 30 / 60).
2. **What's "priority"?** Recommend: integer 0–2 on Habit, matching energy levels (high/mid/low). No separate priority field — your "high energy" habits already are your priorities. Override per user request later.
3. **Should `.deferred` sessions roll forward, or just disappear (per Midnight Hard Reset)?** Spec assumes disappear. v3 says "tomorrow is blank canvas."
