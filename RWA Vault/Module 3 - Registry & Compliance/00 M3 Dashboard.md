---
tags: [rwa-vault, m3, dashboard]
status: in-progress
sprint: 3
updated: 2026-10-27
---
# 🏛️ Module 3 — Registry & Compliance Command Center

> **Purpose:** Real-World Asset Tokenisation & Compliance Engine (ERC-3643 / T-REX + ONCHAINID + AssetRegistry).  
> **Status:** Interfaces scaffolded (`0b2dd0e`). T0.6 verified & checked off. All 16 build decisions locked.

---

## 🧭 Navigation Hub
- **[[00 Dashboard - Project Command Center\|🛸 Main Project Dashboard]]**
- **[[Tasks/M3 Task Board and Todo\|📋 M3 Task Board]]** (T0 to T8)
- **[[Decisions/Open Questions for Fahad\|🎯 M3 Questions Index]]** (Q01 to Q16 - All Decided)
- **[[Decisions/Decisions Log\|📜 M3 Decisions Log]]**

### Folder Structure
- **`Questions/`** — 16 individual question notes with options, rationales, and recorded decisions.
- **`Tasks/`** — Task groups T0 through T8 with concrete checklists and unblock criteria.
- **`Threads/`** — Live agent communication logs ([[Threads/Thread - T0.6 AssetRegistry Interface\|Thread T0.6]], [[Threads/Thread - T6.0 Onboarding Schema & Parity\|Thread T6.0]]).
- **`Specs/`** — In-depth architectural specifications and work orders.
- **`Algorithms/`** — Mathematical admission predicates ([[Algorithms/Mathematics - Admission Predicate and Invariants\|Mathematics]]) and runnable decision flows ([[Algorithms/Decision Algorithms - for Fahad\|Decision Algorithms]]).
- **`Understanding/`** — 5-part conceptual walkthrough from intuition to technical mechanics.
- **`Running/`** — Build, test, and demo commands ([[Running/How to Run Module 3\|How to Run M3]]).

---

## 🚦 Task Lane Summary

| Group | Area | Lead Agent | State | Key Dependency |
|---|---|---|---|---|
| **T0** | [[Tasks/T0 - Interface PR\|Interfaces & Guarantees]] | 🧭 Researcher | 7/8 Done | T0.6 verified; T0.7 spec owed |
| **T1** | [[Tasks/T1 - Identity Layer\|ONCHAINID & Identity Registries]] | ⌨️ Coder | Ready | Vendor `onchain-id` (Q1=C) |
| **T2** | [[Tasks/T2 - Modular Compliance\|ModularCompliance]] | ⌨️ Coder | Ready | `AssetLiveModule` against mock |
| **T3** | [[Tasks/T3 - ERC-3643 Token\|ERC-3643 Token]] | ⌨️ Coder | Ready | One token per asset (ADR 0016) |
| **T4** | [[Tasks/T4 - AssetRegistry & Admission\|AssetRegistry State Machine]] | ⌨️ Coder | Ready | 4-state machine, immutable (ADR 0025) |
| **T5** | [[Tasks/T5 - Wiring & Deployment\|Deployment Scripts]] | ⌨️ Coder | Queued | After T1–T4 unit suites pass |
| **T6** | [[Tasks/T6 - Provider Onboarding Console\|Provider Console & Schema]] | 🐞 Debugger | In Progress | T6.0 Batch 2 rulings ready for Coder |
| **T7** | [[Tasks/T7 - Acceptance & MS1 Readiness\|Acceptance Suite]] | 🧭 Researcher | Queued | Full invariant run |
| **T8** | [[Tasks/T8 - Custodian Attestation Portal\|Custodian Portal]] | 🧭 Researcher | Queued | Distinct key separation |

---

Up: [[00 Dashboard - Project Command Center]] · Parent: [[All Modules]]
