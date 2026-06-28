# UI Spec — memory-vault MVP

Screen-by-screen UX decisions — the **code-facing** layer derived from the
Figma design. Each screen's **UX design** backlog item (EPIC-UI / 1.3 / 1.5 / …)
lands its signed-off Figma frame link + resolved forks + token usage here
**before** the matching build item starts. Pipeline:
[`../process/design-workflow.md`](../process/design-workflow.md). Benchmarks:
TickTick, Habitify, Things3.

- **Figma file:** _TBD — paste the WillPower Figma file URL here once created._
- **Visual source of truth:** Figma. **This doc** translates it for SwiftUI.

Status per screen: 🔵 design pending · ✏️ in design (Figma) · ✅ design locked → build.

---

## App shell & navigation  *(UI.1)* — 🔵
Tabs: Today · Diary · Stats · Profile. Root routing, deep links. *Design pending.*

## Today  *(1.3)* — 🔵
Habits grouped under Morning / Noon / Afternoon / Evening. Check-off rows for
`.checkIn`, count-stepper rows for `.count`. Per-habit streak. Empty / all-done
state. **Open forks** (to resolve here): section layout (collapsible vs flat),
how habits in multiple routines render, ordering within a bucket, where the
add-button lives, the all-done celebration. *Design pending.*

## Add / Edit habit  *(1.5)* — 🔵
Form: title, type (check-in/count), target (count only), category, routines
(multi-select), reminder. Add-button placement + entry animation. *Design pending.*

## Design system  *(UI.2 / UI.3)* — 🔵
Color / type / spacing tokens, light+dark; reusable components (habit row,
check control, count stepper, routine header, empty-state). *Design pending.*

---

> Mood, Diary, Stats, On-this-day, Theme screens get sections here as their
> epics (2/3/4/5/6) enter a sprint and earn a design item.
