---
tags: [rwa-vault, m3, dashboard]
status: in-progress
sprint: 3
updated: 2026-11-12
---
# 🏛️ Module 3 — Registry & Compliance Command Center

> **Purpose:** Real-World Asset Tokenisation & Compliance Engine (ERC-3643 / T-REX + ONCHAINID + AssetRegistry).  
> **Status:** T1 Identity Layer complete (`61f2e90`). T0.6 verified. Q01–Q16, Q17–Q22, Q27–Q28 decided. T2 next.

---

## 🧭 Navigation Hub
- **[[00 Dashboard - Project Command Center\|🛸 Main Project Dashboard]]**
- **[[Tasks/M3 Task Board and Todo\|📋 M3 Task Board]]** (T0 to T8)
- **[[Decisions/Open Questions for Fahad\|🎯 M3 Questions Index]]** (Q01–Q16 decided · Q17–Q22 open)
- **[[Decisions/Decisions Log\|📜 M3 Decisions Log]]**

### Folder Structure
- **`Questions/`** — one Decision note per question (Q01–Q22), with options, recommendation and recorded decision.
- **`Tasks/`** — Task groups T0 through T8 with concrete checklists and unblock criteria.
- **`Threads/`** — Live agent communication logs ([[Threads/Thread - T0.6 AssetRegistry Interface\|Thread T0.6]], [[Threads/Thread - T6.0 Onboarding Schema & Parity\|Thread T6.0]]).
- **`Specs/`** — In-depth specifications and work orders (single canonical copy).
- **`Threads/Rounds/`** — Debugger briefs and question/answer rounds, linked from thread entries.
- **`Algorithms/`** — Mathematical admission predicates ([[Algorithms/Mathematics - Admission Predicate and Invariants\|Mathematics]]) and runnable decision flows ([[Algorithms/Decision Algorithms - for Fahad\|Decision Algorithms]]).
- **`Understanding/`** — 5-part conceptual walkthrough from intuition to technical mechanics.
- **`Running/`** — Build, test, and demo commands ([[Running/How to Run Module 3\|How to Run M3]]).

---

## 🚦 Task Lane Summary

| Group | Area | Lead Agent | State | Key Dependency |
|---|---|---|---|---|
| **T0** | [[Tasks/T0 - Interface PR\|Interfaces & Guarantees]] | 🧭 Researcher | 7/8 Done | T0.6 verified; T0.7 spec owed |
| **T1** | [[Tasks/T1 - Identity Layer\|ONCHAINID & Identity Registries]] | ⌨️ Coder | ✅ Done (`61f2e90`) | 4 contracts, 115 tests, Q27/Q28 decided |
| **T2** | [[Tasks/T2 - Modular Compliance\|ModularCompliance]] | ⌨️ Coder | Ready | `AssetLiveModule` against mock |
| **T3** | [[Tasks/T3 - ERC-3643 Token\|ERC-3643 Token]] | ⌨️ Coder | Ready | One token per asset (ADR 0016) |
| **T4** | [[Tasks/T4 - AssetRegistry & Admission\|AssetRegistry State Machine]] | ⌨️ Coder | Ready | 4-state machine, immutable (ADR 0025) |
| **T5** | [[Tasks/T5 - Wiring & Deployment\|Deployment Scripts]] | ⌨️ Coder | Queued | After T1–T4 unit suites pass |
| **T6** | [[Tasks/T6 - Provider Onboarding Console\|Provider Console & Schema]] | 🧭 Researcher | Blocked (T6.0 in review) | T6.0 VERIFY · T1–T5 · Q17–Q22 |
| **T7** | [[Tasks/T7 - Acceptance & MS1 Readiness\|Acceptance Suite]] | 🧭 Researcher | Queued | Full invariant run |
| **T8** | [[Tasks/T8 - Custodian Attestation Portal\|Custodian Portal]] | 🧭 Researcher | Queued | Distinct key separation |

---

Up: [[00 Dashboard - Project Command Center]] · Parent: [[All Modules]]

## What broke after the PR #2 and PR #5 merge (2026-11-22), and its status
- **Import paths:** fixed. Imports point to `src/vendor/onchain-id/interface/` (ADR 0031).
- **Agent model (Q29):** decided. PR #5 agent roles on `IdentityRegistry`.
- **Storage and issuer contracts:** decided (Q29 Option 1). PR #5 versions, with `InvalidOwner` kept as the named zero-owner error.
- **Test fixes:** KYC topic is not re-added (ADR 0029). Topic limit is 5 (Q27). Zero-owner tests use the named errors.
- **Stale submodule:** `contracts/lib/onchain-id` removed from the index, and stale compiler pins removed from `foundry.toml`.
- **Pull requests (done 2026-11-22):** PR #2 and PR #5 show as merged on GitHub, because their content is now in `feat/finance-modules` (commits `d908166`, `fbe9823`). The branch is pushed at `137b640`.
- **Still open:** merge `feat/finance-modules` into `main`, only after Fahad approves.
- **Repository branches (done 2026-11-22):** `feat/finance-modules` is the GitHub default branch. `codex/module-1` is deleted; its history is kept at tag `archive/codex-module-1`.
