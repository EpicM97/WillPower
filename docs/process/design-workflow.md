# Process — UI/UX Design Workflow (E2E)

> The single pipeline every user-facing feature flows through, with design as a
> first-class phase. Pairs with [`scrum.md`](scrum.md) (cadence/DoR/DoD) and
> [`qa-test-automation.md`](qa-test-automation.md) (QC). Code-facing screen
> decisions live in [`../product/ui-spec.md`](../product/ui-spec.md).

## The end-to-end loop (one feature, start to ship)

```
1. Requirements   PRD.md — vision, MOAT, the user outcome
        │
2. UX design      Figma — flows → wireframes → hi-fi screens, on the design system
        │         (Claude can generate frames into Figma via the MCP, or Minh
        │          designs by hand — either way the PO signs off in step 3)
        │
3. Design review  PO (Minh) signs off the Figma frames; open forks resolved.
   & sign-off     Hard-to-reverse calls → ADR in architecture/decisions.md
        │
4. Spec           ui-spec.md — code-facing: layout, components, states, tokens,
        │         derived from the approved Figma frame (+ Figma node link)
        │
5. Build          SwiftUI, HARNESS-FIRST (failing test → logic). Claude reads the
        │         Figma frame via the Dev Mode MCP for pixel/token fidelity.
        │
6. Test / QC      XCTest (logic) + Maestro (E2E smoke) + visual check vs Figma
        │         (on-device side-by-side; snapshot tests where churn is low)
        │
7. Review/Deploy  Sprint review on-device against acceptance + the Figma design;
        │         CI green → TestFlight
        │
8. Maintain       implementation-plan.md changelog + backlog status
```

**The gate (design-before-build):** a build story is **not DoR-ready** until its
design item is `✅` — meaning the Figma frame is signed off **and** its
`ui-spec.md` section is written. No building screens off vibes.

## Tooling & sources of truth
| Concern | Tool | Source of truth |
|---|---|---|
| Visual design (flows, screens, hi-fi) | **Figma** | the Figma file |
| Figma ↔ Claude (both ways) | **Figma MCP** (official hosted plugin, `mcp.figma.com/mcp`) | read **and** write/generate; see below |
| Code-facing screen spec | `ui-spec.md` | this repo |
| Implementation | SwiftUI | `Sources/` |
| Design tokens | Figma variables → mirrored as Swift `DesignTokens` | both, kept in sync |

### Figma MCP — read **and** write (official hosted plugin)
Installed as the `figma` plugin (hosted server `https://mcp.figma.com/mcp`).
Bridges code ↔ design **both directions**. (The earlier local Dev Mode server —
which *was* read-only — has been removed; this plugin supersedes it.)
- **Read (design → code):** `get_design_context`, `get_screenshot`,
  `get_metadata`, `get_variable_defs` — pull a frame's structure/tokens to
  implement SwiftUI to match.
- **Write / generate (code or intent → design):** `generate_figma_design`,
  `create_new_file`, `use_figma`, `upload_assets` — Claude can **create and edit
  Figma files**. **Mandatory:** load the matching skill *before* the write tool —
  `/figma-create-new-file`, `/figma-generate-design`, `/figma-generate-library`,
  `/figma-use`, or `/figma-swiftui` (the SwiftUI↔Figma translator).
- **Workflow (either origin):** ① Claude generates frames into Figma from
  `ui-spec.md`/intent → PO reviews → tweak; **or** ② Minh designs in Figma →
  Claude reads via MCP. Either way: sign-off → record the Figma node link in
  `ui-spec.md` → build SwiftUI → verify fidelity.

## Design system (the substrate — EPIC-UI)
Built once, reused everywhere. Lives as Figma variables **and** a Swift
`DesignTokens` mirror so design and code never drift.
- **Tokens:** color (semantic: bg/surface/text/accent, light+dark), type scale
  (SF, Dynamic Type ramp), spacing (8pt grid), radius, elevation.
- **Components:** habit row, check-off control, count stepper, routine section
  header, empty/all-done state, primary/secondary button, form field.
- **Screens:** app shell (tab bar), Today, Add/Edit habit, then per-epic.

## Standards (current iOS / product-design best practice)
- **Apple HIG** alignment; native components/patterns first.
- **8pt spacing grid**; **44×44pt** minimum touch targets.
- **Dynamic Type** support; no clipped text at XXL.
- **Color contrast ≥ WCAG AA** (4.5:1 body, 3:1 large/UI).
- **Dark mode** is not optional — every screen designed in both.
- **VoiceOver**: every interactive element has a label + trait.
- **Motion**: respect Reduce Motion; transitions purposeful, not decorative.

## Design review checklist (PO sign-off in step 3)
- [ ] Solves the PRD user outcome; matches the MOAT (memory-vault feel).
- [ ] Light **and** dark frames present.
- [ ] All states drawn: empty, loading, error, success/all-done.
- [ ] Touch targets ≥ 44pt; spacing on the 8pt grid.
- [ ] Contrast + Dynamic Type sanity-checked.
- [ ] Benchmarked against TickTick / Habitify / Things3 — and a reason it's ours.
- [ ] Open forks listed in `ui-spec.md` are all resolved.

## Visual QA (step 6)
- **Logic** → XCTest (harness-first, the hard gate).
- **Flows** → Maestro smoke (the E2E half of the QC stack).
- **Fidelity** → on-device side-by-side vs the Figma frame during sprint review;
  add SwiftUI **snapshot tests** for stable, high-value components once the
  design system settles (avoid snapshotting churny screens).
