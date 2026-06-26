# Architecture Proposal

> Drafted by Claude per the PRD's Architecture stub. Decision-oriented: read the
> TL;DR, then the **Platform** section (it's the pivot). Once you've reviewed,
> I'll fold the summary into `product/PRD.md` and log the decisions.

## TL;DR — what I recommend

| Concern | Recommendation | The pivot / risk |
|---|---|---|
| Platform | **Native iOS-first (SwiftUI), Android as a native fast-follow (Compose)** sharing the same backend | Means Android is **not** at Q3 launch — needs a roadmap tweak, or we pay the cross-platform rewrite cost |
| On-device AI | **MLX** runtime + a 1–3B 4-bit model, **RAG** over the diary (not fine-tuning) | The moat engine — gets its own section |
| Vector store | **SQLite + sqlite-vec** (local, embeddable) | Personal-scale; brute-force cosine is fine early |
| Embeddings | Apple **NaturalLanguage** built-in for MVP → upgrade to `bge-small` later | Zero model download for MVP |
| Backend | **Keep Supabase** (Postgres + Auth + RLS + Storage + Edge) | Don't migrate to raw AWS/GCP/Azure; revisit only at much larger scale |
| Diary security | **AES-256-GCM, key in Secure Enclave/Keychain, Face ID/PIN gate** | Replaces "blockchain" — already 80% built |
| Cross-device key (V1) | **iCloud Keychain** (iOS) or **passphrase-derived (Argon2id)** | The hard part of E2EE+sync; MVP is single-device so we defer it |

---

## 1. Platform — the decision that gates everything

Your roadmap says "Q3: iOS **& Android**." That one line decides the whole stack, because **most of WillPower's flagship/moat features are native-first**:

| Feature | iOS-native cost | Cross-platform cost |
|---|---|---|
| On-device LLM (recall/Jarvis) | MLX / llama.cpp — first-class | Native module per platform anyway |
| E2EE in Secure Enclave + Face ID | Keychain + LocalAuthentication — trivial | Native module per platform |
| Live Activities / Dynamic Island | WidgetKit — native-only | Native-only regardless |
| Home-screen widgets | WidgetKit | Native-only regardless |
| Lock-in mode | Screen Time / FamilyControls — native-only | Native-only regardless |
| Apple Health | HealthKit | Native module |

The cross-platform promise (one UI codebase) **doesn't save you** on the features that make WillPower special — those need native modules either way. And we already have ~half an MVP in SwiftUI (the diary, on-this-day, theme, auth, sync).

**Recommendation: native iOS-first; Android as a native (Jetpack Compose) fast-follow** sharing the same Supabase backend and the same on-device-AI approach (MLC-LLM/llama.cpp on Android). Honest cost: **Android won't make a Q3 launch** — I'd revise the roadmap to *Q3 iOS → Q4/Q1 Android*.

**If Android-at-launch is non-negotiable** (a real business reason), then the alternative is:
- **KMP (Kotlin Multiplatform)** — share domain/logic in Kotlin, keep native UIs (SwiftUI + Compose). Most native-feeling; partial rewrite.
- **Flutter / React Native** — share the UI too, but still native modules for every flagship feature, *and* the current 176-test SwiftUI build becomes throwaway except the backend + concepts.

This is the one decision I can't make for you. Everything below assumes the **native iOS-first** path; I'll note where cross-platform changes it.

> ⚠️ Note: "ShadcnUI" from the earlier stub is a **web** (React + Tailwind) kit — it has no native-mobile target, so it can't deliver "consistent design on iOS & Android." Drop it from the plan; if we ever go cross-platform we'd pick a native-mobile UI kit.

---

## 2. On-device AI — the moat engine ("re-live, searchable, private")

This is the differentiator, so it gets the most detail. **Everything here runs on-device; the diary never leaves encrypted.**

**Correcting the stub:** you don't "retrain Llama via app updates." Two separate things:
- **Model weights** are *versioned and downloaded* (app update or background fetch) — that's how the base model improves.
- **Personalization** = **RAG (Retrieval-Augmented Generation)**: we retrieve the user's *own* relevant entries and feed them to the model as context at query time. No training, no fine-tuning, zero data leaves the device. (A future option is lightweight on-device LoRA, but it's not needed for the moat.)

**The pipeline:**
```
Diary entry written
  → decrypt in memory → embed on-device → store vector locally (encrypted index)
User asks "How did I feel about work last month?" / On-This-Day surfaces a memory
  → embed the query → top-k vector search → pull those (decrypted) entries
  → feed entries + question to the local LLM → grounded answer, on-device
```

**Components (iOS):**
- **LLM runtime: MLX** (`mlx-swift`) — Apple-Silicon-native, actively developed, good Swift API. Alt: `llama.cpp` (more portable → reuse for Android).
- **Model:** a **1–3B 4-bit quant** — Llama 3.2 3B Instruct, Qwen2.5 3B, or Gemma 2 2B (~1–2 GB). **Download on first launch**, don't bundle (keeps the app small). Ship model-version updates server-side.
- **Embeddings:** **Apple `NaturalLanguage` sentence embeddings** for MVP (built-in, no download, on-device). Upgrade path: a small model (`bge-small`/`gte-small`, ~30–130 MB) for better recall quality.
- **Vector store:** **SQLite + `sqlite-vec`** (tiny, embeddable, lives next to our existing SQLite/SwiftData). For a personal corpus (hundreds–low-thousands of entries) even brute-force cosine is fine; `sqlite-vec` gives headroom. Alt: `USearch` (HNSW, Swift bindings).
- **Privacy of the index:** the vector index is derived from plaintext, so it's **as sensitive as the diary** → keep it **local-only** (never synced) for MVP, or sync it **encrypted** later. Embeddings are computed only after biometric unlock.

**Scope:** MVP can ship recall/On-This-Day with embeddings + search **without** the LLM (cheaper, still useful). The generative "Jarvis" assistant is a **V1** feature — but the data plumbing (embeddings + vector index) should land in MVP so V1 just adds the generation layer.

---

## 3. Data & storage

| Layer | Tech | Holds |
|---|---|---|
| Structured (local) | **SwiftData** (existing) | Habits, Routines (time-of-day buckets), Categories, Moods, daily check-ins/counts, Projects |
| Diary ("unstructured") | SwiftData/SQLite, **ciphertext at rest** | Encrypted entries + image refs (images encrypted in app-group/file store) |
| Vector index | **SQLite + sqlite-vec**, local-only | Embeddings for recall/RAG |
| Backend | **Supabase** (Postgres) | Synced structured data (RLS per-user) + diary **ciphertext** (V1 sync) + Storage for encrypted blobs |

The stub's "Vectorized DB + Unstructured DB" maps to: **vector index = sqlite-vec (local)**; **unstructured = the encrypted diary store**. No separate server DBs needed for MVP.

> 💡 On "AWS/Google/Microsoft" for cloud sync: Supabase *is* managed Postgres (on AWS underneath) and already gives us Auth + RLS + Storage + Edge Functions, which we've built against. Keep it — it scales well past 20K MAU. Self-host/migrate only if cost or scale ever demands it.

---

## 4. Privacy & security

- **Diary E2EE:** AES-256-GCM (CryptoKit) — *we already have `JournalCrypto`/`JournalKeyStore`*. Add a **Face ID/Touch ID gate** (LocalAuthentication) + PIN fallback to *open* the diary. Key sits in the Keychain, ideally **Secure-Enclave-protected**.
- **Structured data:** per-user **RLS** on Supabase (`user_id default auth.uid()`), already in place.
- **AI = zero egress:** model + embeddings + RAG all on-device. No diary text ever hits a server or any provider.
- **Sharing tiers (V2):** User → Trusted → Friends. Sharing the diary means **re-encrypting a copy to the grantee's public key** (envelope encryption) — the only sanctioned decrypt path beyond the owner. Design later; keep the door open by storing per-entry content keys now.
- **Lock-in mode (V2):** iOS **Screen Time API** (`FamilyControls` + `ManagedSettings` + `DeviceActivity`) — needs Apple's **Family Controls entitlement** (special approval; budget time for it).

## 5. Sync & cross-device E2EE

- **MVP = single-device, local-only** (sync is V1). Privacy-safe and simpler; state it as a deliberate choice.
- **V1 sync:** structured data syncs normally (RLS); the diary syncs as **ciphertext only**; vector index stays local (or syncs encrypted).
- **The hard part — the key across devices:** for a second device to read the diary it needs the symmetric key. Two clean options:
  - **iCloud Keychain** sync of the key (Apple-E2EE, frictionless, iOS-only) — best for the native-iOS path.
  - **Passphrase-derived key (Argon2id)** — user enters a passphrase on each device to derive the same key; cross-platform, but UX friction + unrecoverable if forgotten.
  - Recommend **iCloud Keychain** while iOS-only; switch to/offer passphrase when Android lands.

## 6. Code architecture (native iOS) & reuse

Keep the current clean layering — SwiftUI + SwiftData + repository pattern + pure `Logic/` with harness-first tests. Changes:

**Reuse as-is:** `JournalCrypto`/`JournalKeyStore` (+ add biometric gate) · `OnThisDaySelector` + Memories · theme/background system · Auth · Supabase sync plumbing (parked for V1) · OKR models (V1 projects) · widget scaffolding (V1).

**New modules:**
- `AI/` — `LLMRunner` (MLX), `Embedder` (NaturalLanguage→model), `VectorIndex` (sqlite-vec), `RAG` (retrieve→assemble→generate).
- `Security/` — `DiaryVault` (crypto + biometric gate).
- `Domain/` — `Routine` (time-of-day bucket), `Mood`, simplified `Habit` (type/category/routine), `CheckIn`.

**Scrap:** the budget engine — `BudgetRecalculator`, day-window budget, `HabitKind`/anchored, interruption injector, `MinutesField`/`MinutesInput`, compression, discipline-as-budget.

## 7. Architectural scope by tier

- **MVP:** native iOS · SwiftData · simplified habit/routine/mood/checkin · E2EE diary + Face ID · embeddings + vector index (recall/On-This-Day, no LLM yet) · stats · theme · single-device.
- **V1:** local LLM (Jarvis) over the existing RAG plumbing · Supabase sync (premium) + cross-device key (iCloud Keychain) · projects · widgets.
- **V2:** Android (native Compose) · sharing tiers (envelope encryption) · lock-in mode (Screen Time) · integrations · white noise · countdown · quotes.

## 8. Open decisions (mirror to PRD log)
- [ ] **Platform**: native iOS-first (recommended; Android fast-follow) vs cross-platform rewrite now (KMP/Flutter).
- [ ] **Roadmap**: if native-first, revise "Q3 iOS & Android" → "Q3 iOS, Q4/Q1 Android."
- [ ] **LLM in MVP or V1**: recommend embeddings/recall in MVP, generative assistant in V1.
- [ ] **Cross-device key (V1)**: iCloud Keychain vs passphrase.
- [ ] **Backend**: confirm staying on Supabase (recommended).
