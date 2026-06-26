# QC — Test Automation Research & Recommendation

**Context that decides fit:** WillPower MVP is a **native iOS (SwiftUI)** app,
built **harness-first** (tests before logic), by a **solo founder + AI pair**,
and it holds a **private E2EE diary** (privacy is a hard constraint). Android is
a *later* native port. That context rules some popular tools in and others out.

## The landscape (2026)

| Tool | Layer | Platform | Setup | AI | Fit for us |
|---|---|---|---|---|---|
| **XCTest** | Unit / logic | iOS native | trivial (in Xcode) | — | ✅ **Foundation** — already our 176 harness-first tests |
| **XCUITest** | UI / E2E | iOS native only | low (Apple, in Xcode) | — | ✅ Precision native flows (Face ID gate, diary unlock) |
| **Maestro** | UI / E2E | iOS + Android | **lightest** (YAML flows) | partial | ✅ **Primary E2E** — fast, solo-friendly, local |
| **TestSprite** | AI E2E gen | iOS/Android/web | low (cloud + **MCP**) | ✅ native | ⚠️ Trial — *MCP plugs into Claude Code*, but cloud sandbox (privacy caveat) |
| **Appium** | UI / E2E | iOS + Android + web | heavy | via add-ons | 🔵 **Later** — when Android lands (cross-platform suite) |
| **EarlGrey** | UI / E2E | iOS native | medium | — | 🔵 Optional — Google's anti-flake synchronization |
| **Drizz** | AI E2E | mobile | low | ✅ Vision-AI, plain English | 👀 Watch — emerging, plain-English flows |
| **Playwright** | UI / E2E | **web only** | low | — | ❌ **Not for native iOS** — web surfaces only |

### Notes that matter
- **Playwright** is a **web** framework (Microsoft). Its "mobile" support is *mobile-web emulation* (viewports), **not native iOS app automation**. It becomes relevant only if/when we build a **marketing site or web app** — keep it on the shelf for that, not the app.
- **TestSprite** is genuinely interesting for us: its **MCP server integrates with Claude Code**, reads the **PRD**, infers intent, and generates runnable **Appium** tests (gestures, permissions, backgrounding, network loss). For a solo founder that's a real force-multiplier — but it runs in a **cloud sandbox**, which collides with our privacy promise (see caveat).
- **XCUITest** is Apple-native: fastest/most stable for pure iOS, but iOS-only and Swift-bound — perfect for the few flows that *must* be precise.
- **Maestro** wins on setup cost and readability (YAML flows), runs locally, and already speaks both iOS and Android — so it survives the Android port.

## Recommendation (phased)

**Now (MVP, iOS) — adopt:**
1. **XCTest** — keep as the harness-first foundation (unit + pure logic). *Gates every story.*
2. **Maestro** — primary **E2E smoke + happy-path flows** (onboarding, add habit, check-off, mood, diary unlock). Cheap to write, runs locally in CI.
3. **XCUITest** — a *small* set of precision native tests where Maestro is too coarse: **Face ID / PIN gate**, diary lock/unlock, notification permission.
4. **CI**: GitHub Actions (macOS runner) or **Xcode Cloud** running `make test` + the Maestro suite on every push.

**Trial (parallel, low commitment):**
- **TestSprite via MCP in Claude Code** — let it draft Appium flows from the PRD as a productivity experiment. **Only against seeded/synthetic data**, never a real diary (see caveat). Keep it if the generated flows save real time; drop it if it's noise.

**Later:**
- **Appium** — when **Android** lands, for a single cross-platform suite. Revisit Maestro-vs-Appium then.
- **Playwright** — if/when there's a **web** marketing site or web app.

## 🔒 Privacy caveat (non-negotiable for a vault app)
Cloud-based AI testers (TestSprite, device clouds) **ingest screenshots/recordings**. Never point them at real journal data.
- Run anything touching the **diary** with **local execution** (XCUITest/Maestro on a local sim/device).
- Seed tests with **synthetic** entries only.
- Treat "where do test artifacts (screens/videos) get stored" as a security review item before adopting any cloud tester.

## Definition-of-Done tie-in (see `scrum.md`)
- **Every story:** XCTest unit/logic coverage, green.
- **User-facing story:** at least one **Maestro smoke flow**.
- **Security-sensitive flow** (diary, auth): an **XCUITest** assertion, run locally.

## Sources
- [Top iOS testing tools 2026 — testgrid.io](https://testgrid.io/blog/best-ios-testing-tools/)
- [11 mobile test automation tools compared (2026) — drizz.dev](https://www.drizz.dev/post/best-mobile-test-automation-tools)
- [TestSprite — AI mobile/iOS testing + MCP](https://www.testsprite.com/use-cases/en/ai-ios-testing-tool)
- [Apidog — top iOS automation tools 2026](https://apidog.com/blog/ios-automation-testing-tools/)
