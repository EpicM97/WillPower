# WillPower — Documentation

SDLC documentation map. Source of truth for *what we're building*, *how it's
designed*, and *what's next*.

```
docs/
├── product/
│   ├── PRD.md              ⭐ Shared product brief & plan (vision, MOAT, features, roadmap) — edit together
│   ├── backlog.md          Product backlog (memory-vault MVP: epics → stories)
│   ├── ui-spec.md          Screen-by-screen UX decisions (design-before-build)
│   └── test-plan.md        Manual QA test pass (legacy budget-era — to be refreshed)
├── process/
│   ├── scrum.md            SDLC + Scrum (cadence, DoR/DoD, sprint plan)
│   ├── design-workflow.md  UI/UX pipeline (Figma → review → spec → build → QA)
│   └── qa-test-automation.md  QC tooling research & recommendation
├── architecture/
│   ├── overview.md         Layers, tech stack, folder layout
│   ├── tech-spec.md        Consolidated system design (the engineering reference)
│   └── decisions.md        ADRs — the "why" behind irreversible choices
├── specs/
│   ├── elastic_compression.md   Budget compression algorithm spec
│   └── discipline_score.md      Discipline scoring spec
└── operations/
    └── (see ../SUPABASE_SETUP.md for the Supabase runbook)
```

## Where things live
| You want… | Read |
|---|---|
| What to build next | [product/backlog.md](product/backlog.md) |
| How design → code flows | [process/design-workflow.md](process/design-workflow.md) |
| Per-screen UX decisions | [product/ui-spec.md](product/ui-spec.md) |
| What to manually test | [product/test-plan.md](product/test-plan.md) |
| How a system works | [architecture/tech-spec.md](architecture/tech-spec.md) |
| Why we chose X | [architecture/decisions.md](architecture/decisions.md) |
| The chronological build log | [../implementation-plan.md](../implementation-plan.md) (engineering changelog) |
| Supabase setup / CLI | [SUPABASE_SETUP.md](SUPABASE_SETUP.md) |
| Project rules for contributors/agents | [../CLAUDE.md](../CLAUDE.md) |

## Document roles (SDLC)
- **`implementation-plan.md`** — append-only **changelog**: every phase, what shipped, test counts. History.
- **`product/backlog.md`** — the **forward** view. Nothing here has shipped yet (or it's a known gap).
- **`architecture/tech-spec.md`** — the **design reference**: current-state, kept accurate.
- **`architecture/decisions.md`** — **ADRs**: one entry per hard, hard-to-reverse decision.
