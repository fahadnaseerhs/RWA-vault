---
tags: [rwa-vault, m3, tasks, board]
status: ready-to-code
updated: 2026-10-27
---
# 📋 Module 3 — Master Task Board

> **The Done Rule:** A task is checkmarked ONLY when the Researcher verifies its acceptance criteria on disk.  
> Status and subtasks live inside each task note in `Module 3 - Registry & Compliance/Tasks/`.

| Group | Task Name | Status | Lead Agent | Unblocked By | Details & Thread |
|---|---|---|---|---|---|
| **T0** | [[Tasks/T0 - Interface PR\|Interface PR & Behavioural Spec]] | 🔵 In Progress (7/8) | 🧭 Researcher | — | [[Threads/Thread - T0.6 AssetRegistry Interface\|Thread T0.6]] |
| **T1** | [[Tasks/T1 - Identity Layer\|Identity Layer (ONCHAINID + Registries)]] | 🟢 Ready to Code | ⌨️ Coder | Q01, Q02, Q03 | Scaffold ready |
| **T2** | [[Tasks/T2 - Modular Compliance\|Modular Compliance (AssetLiveModule)]] | 🟢 Ready to Code | ⌨️ Coder | Q04, Q06 | Built against `AssetRegistryMock` |
| **T3** | [[Tasks/T3 - ERC-3643 Token\|ERC-3643 Permissioned Token]] | 🟢 Ready to Code | ⌨️ Coder | Q08, Q10, Q16 | ADR 0015, 0016 |
| **T4** | [[Tasks/T4 - AssetRegistry & Admission\|AssetRegistry & Admission Predicate]] | 🟢 T4.1 ready · T4.2/T4.4 wait | ⌨️ Coder | Q13, Q14, Q15 · Q17, Q18 open | T4.1 ready |
| **T5** | [[Tasks/T5 - Wiring & Deployment\|Wiring & Deployment]] | ⏳ Queued | ⌨️ Coder | Q07, Q15 | After T1–T4 tests pass |
| **T6** | [[Tasks/T6 - Provider Onboarding Console\|Provider Onboarding Console]] | ⛔ Blocked · T6.0 in review | 🧭 Researcher | Q09, Q12 · Q17–Q22 decided · T1–T5 | [[Threads/Thread - T6.0 Onboarding Schema & Parity\|Thread T6.0]] |
| **T7** | [[Tasks/T7 - Acceptance & MS1 Readiness\|Acceptance & MS1 Readiness Gate]] | ⏳ Queued | 🧭 Researcher | All | Milestone 1 Gate |
| **T8** | [[Tasks/T8 - Custodian Attestation Portal\|Custodian Attestation Portal]] | ⏳ Queued | 🧭 Researcher | C1 | Key separation |

---

## ▶️ Build order (Q19 = A, 2026-10-28)
T6.0 VERIFY → T6.2 protocol → T1.1 → T4.1 → T2 → T3 → T5.1 → T6.1a → T6.3 → T6.1b → T7.

## ⚡ Active Execution Threads
1. **[[Threads/Thread - T0.6 AssetRegistry Interface]]** — T0.6 completed & verified by Researcher.
2. **[[Threads/Thread - T6.0 Onboarding Schema & Parity]]** — Batch 2 applied, 32/32 green; awaiting Researcher VERIFY.

Up: [[00 M3 Dashboard]] · Related: [[Decisions Log]], [[Open Questions for Fahad]]
