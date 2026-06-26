# WillPower — Product Brief & Plan

> **Our shared working doc.** Ported from the Apple Notes "WillPower" + the
> Features Breakdown PDF so we can both edit it in-repo.
>
> **Conventions**
> - Plain text = agreed / your source of truth.
> - `> 💡 Claude:` = a suggestion from me to accept or reject (edit freely).
> - `🟡 TBD` = open / undecided.
> - When you change this, tell me to re-read it; when I propose, I use callouts, not silent rewrites.

---

## Idea
**A better life that can be remembered.**

> 💡 Claude — optional positioning one-liner to sit under the Idea:
> *"WillPower is the private memory vault for people improving their lives — it remembers what you did, how you felt, and what it meant, so you can re-live it."*

## MOAT
The only private place that unites **what you did**, **how you felt**, and **what it meant** into a life you can **re-live** — searchable by a fully on-device AI, owned only by you, shared only in tiers you control. Competitors track one layer; none turn self-improvement into a private, remembered life. That synthesis + true privacy + local-AI recall is the defensible edge.

---

## Market research

### Competitors
Things3 · TickTick · Habit Tracker (InnerGrow) · Habitify

### Observation canvas

**Things3** — *Purely to-do & scheduling · 1-time payment*
- Features: To-do list, grouping, checklist, reminder (all premium)
- ✅ Smart layout · simple UI, no noise · easy onboarding
- ❌ Boring, low moat · iOS only · no advantage vs others

**TickTick** — *To-do + scheduling + habit · subs & 1-time*
- Features: task mgmt multi-view (list/kanban/gantt, premium) · reminder · habit tracker · pomodoro · Eisenhower matrix · countdown · task sharing/friends · stats+streaks (premium) · theme switcher (premium) · AI summary (premium)
- ✅ Smart view options · integrations · Eisenhower · habits-as-tasks under task mgmt · calendar UI for habit streaks · notes + mood log per task/habit · AOD pomodoro/stopwatch · timeline view (creative for routine tracking)
- ❌ Hard to onboard (flow, settings) → **critical** · noisy UI (too many things) → low retention → **critical** · makes simple things "fancy" by gating them premium (background/white-noise/theme/annual heatmap/calendar/AI voice) · settings buried on the default task-mgmt tab · stats are a web-view, not native → inconsistent

**Habit Tracker (InnerGrow)** — *Habit · subs & 1-time*
- Features: habit tracker · reminder (premium) · mood logger · stats · friend group habits · reports (premium) · widgets · wallpaper (premium) · cloud sync
- ✅ Location arrive/leave reminders · split habit by category/time-range/type · Apple Health (wind-down data) · varied done-marking (stacking e.g. 3 cups/day + one-shot) · "don't" habits to break bad patterns · smart report layout (habit as horizontal menu item)
- ❌ Bad UX merging habit-menu + add-button into one icon · no way to unhide a habit (confused with archive) · too many settings, no section titles · about-section inside the app = clutter

**Habitify** — *Habit · subs & 1-time*
- Features: habit tracker · friends sharing · calendar (premium) · deep insights/reports (premium) · off mode (premium)
- ✅ Smart add-habit (add button in navbar) · strong AI "magic fill" (auto-name + ideal configs) · clean habit UI (diary + stats in one page via tabs) · wide integrations
- ❌ 3rd-party activity clutter (strava/fitbit/health) — should be nested/compact · simple-but-cheap design gets boring · no wind-down setup (only start-day-of-week) · confusing log feature · no mood log · no theme/wallpaper · no widgets

### Things in common (table-stakes — parity, *not* differentiators)
Every credible app in this space ships these; we must too, but they win nothing on their own:
- Add / edit / archive a habit
- Daily check-off + count-type habits
- **Streaks** + completion %
- Reminders / notifications
- Time-of-day organization
- Basic stats (calendar heatmap, weekly/monthly)
- Cloud sync
- Widgets
- Light/dark + theming
- Clean, fast onboarding

---

## Feature breakdown

| # | Tier | Feature | Why | How |
|---|------|---------|-----|-----|
| 1 | **MVP** | Habit (Routine) tracking | Core value — define a better person via a healthy lifestyle | Habit structured by **Routine** (time-of-day: Morning/Noon/Afternoon/Evening), **Type** (Check-in / Count), **Category** (Health / Lifestyle). A habit can be in 1+ routines/day; type & category are 1 each. Optional location → arrive/leave check-in. |
| 2 | **MVP** | Mood control | Mindfulness — a place to express how you feel and feel a bit better | 5-point scale Euphoric > Happy > Neutral > Sad > Horrible. Triggers after a routine is completed & notes captured; shown again in end-of-day stats after the diary. |
| 3 | **MVP** | Private diary (E2EE) | Every valued moment is worth keeping — the happy and the hard | On-device **E2EE** (AES-GCM; key in Secure Enclave/Keychain). Opens only with **Face ID / PIN** (LocalAuthentication). *Not blockchain.* |
| 4 | **MVP** | On-this-day | Never miss an anniversary / a memory | Rewind by habit creation date, first achievement, memories. |
| 5 | **MVP** | Statistics reports | Look back on how tough/good the journey was | Habit performance + mood change: daily / weekly / monthly / yearly. |
| 6 | **MVP** | Theme switcher | Stay un-bored with change | Stock themes + local photos, plus light/dark. |
| 7 | **V1** | Projects / Goals | Balance work & life (IKIGAI) | Personal project tracking; premium 2-way sync to Jira/Teams. |
| 8 | **V1** | Widgets | Quick access on the go | Home-screen widgets for Habit + Mood. |
| 9 | **V1** | AI assistant | A "Jarvis" optimizing routine + schedule for work-life balance | Local LLM, on-device. |
| 10 | **V1** | Cloud sync | Don't lose moments if a device is lost/stolen | Premium — sync to WillPower server. |
| 11 | **V2** | Friends / social graph | Connect with people you love | Find friends (permission-gated): contacts, FB, IG, X, Snapchat, Threads. |
| 12 | **V2** | 3rd-party integration | Bind other apps' schedules for smarter days | Projects: Teams/Jira/Slack. Occasions/booking: Google Calendar/Gmail. |
| 13 | **V2** | White noise | Ambient sound during habits/pomodoro without leaving the app | Built-in noise or embedded source. |
| 14 | **V2** | Countdown | Be reminded of occasions anywhere | Location/timezone → national + personal occasions (DOB, nationality, marital date, honors; "time-in" when travelling). |
| 15 | **V2** | Quote of the day | Stay motivated, contextually | Quotes from trusted sources (e.g. Wikiquote); local LLM picks the closest to your recent routine/mood/habit. |
| 16 | **V2** | Lock-in mode | Beat ADHD/procrastination when locked in | "God mode" — no distractions during a habit except whitelisted contacts/apps. |

**Vocabulary (locked):** a **Habit** has one *type* (check-in | count) + one *category* (health | lifestyle) and belongs to **1+ Routines**, where a **Routine = a time-of-day bucket** (Morning/Noon/Afternoon/Evening). "Routine" never means "the daily set."

**Sequencing:** diary is MVP but **sync is V1** → **MVP is single-device / local-only** (privacy-safe by default). When sync lands, the cloud holds diary **ciphertext only**.

> ✅ Corrections applied: blockchain→E2EE (#3) · routine-isn't-the-moat (#1, kept as parity UX) · vocabulary locked · Neutral · Wikiquote.

---

## Roadmap
- **2026/Q3** — Launch on **iOS** (native) — *Android fast-follow Q4–Q1 per architecture rec; revert to "iOS & Android" only if Android-at-launch is mandatory*
- **2026/Q4** — 1,000 MAU
- **2027/Q1** — first half of V1 shipped · 3,000 MAU
- **2027/Q2** — all of V1 shipped · 5,000 MAU
- **2027/Q3** — first half of V2 shipped · 10,000 MAU
- **2027/Q4** — all of V2 shipped · 20,000 MAU

## Plan
- **2026/Q3** — MVP
- **2026/Q4** — MVP enhancement
- **2027/Q1** — ½ V1 shipped · bug fixes + security hardening
- **2027/Q2** — full V1 · bug fixes + performance
- **2027/Q3** — ½ V2 · bug fixes + performance
- **2027/Q4** — full V2 · bug fixes + performance

---

## Architecture
> Summary reconciled from **[`../architecture/architecture-proposal.md`](../architecture/architecture-proposal.md)** (full detail + tradeoffs there).

- **Platform (recommended):** **native iOS-first (SwiftUI); Android a native fast-follow (Compose)** sharing the Supabase backend. The moat features (on-device LLM, Secure-Enclave E2EE, Live Activities, widgets, lock-in, HealthKit) are native-first — cross-platform adds a layer without saving that work, and we'd discard ~half a working MVP. **Drop ShadcnUI/React** (web-only; can't be "consistent on iOS & Android").
- **On-device AI (the moat engine):** **RAG, not fine-tuning** — embed the diary on-device → vector search → feed *your own* entries to a local 1–3B model → grounded, **zero-egress** answers. Stack: **MLX** runtime + **sqlite-vec** index + Apple `NaturalLanguage` embeddings (MVP). Model weights are *downloaded/versioned*, never "retrained via app updates."
- **Data:** local **SwiftData** (structured) + **ciphertext** diary + local-only **vector index**. Backend stays **Supabase** (Postgres/Auth/RLS/Storage/Edge — scales past 20K MAU; no need for raw AWS/GCP/Azure).
- **Privacy:** AES-256-GCM diary, Secure-Enclave key, Face ID/PIN gate; per-user RLS; AI fully on-device. Sharing tiers (V2) via envelope encryption. Lock-in (V2) via Screen Time / FamilyControls (needs Apple's special entitlement).
- **Sync (V1):** structured syncs under RLS; diary syncs as **ciphertext**; cross-device key via **iCloud Keychain** (iOS) or passphrase.
- **Reuse vs scrap:** keep `JournalCrypto`/`JournalKeyStore`, On-This-Day, theme system, auth, sync plumbing, OKR models, widget scaffolding. **Scrap** the whole budget engine.
- Cloudflare (DNS/CDN) — fine for the marketing site; not part of the app core.

## Revenue model
- Monthly / yearly subscriptions only (unlock all features). **No in-app ads.**

## Go-to-market
- Paid acquisition: Meta / X / YouTube
- Marketplace ads: App Store / Google Play

---

## Decisions & open questions (running log)
- [x] **MOAT wording** — adopted the tightened "did / felt / meant → re-live" version.
- [x] **Diary tech** — on-device E2EE + Face ID/PIN (blockchain dropped).
- [x] **Architecture proposal** — drafted (`../architecture/architecture-proposal.md`) + summarized above.
- [~] **Platform** — *recommended:* native iOS-first, Android fast-follow. **Needs your confirm/override** — this is the one that gates code work.
- [x] **MVP cross-device** — confirmed **single-device** for MVP (sync = V1).
- [~] **Roadmap** — revised to "Q3 iOS, Android Q4–Q1" pending the platform call.
- [ ] **Build refactor** — turn keep/rework/scrap into a sequenced MVP plan (next, after platform confirm).
