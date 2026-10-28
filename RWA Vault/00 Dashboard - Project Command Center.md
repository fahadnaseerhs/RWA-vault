---
tags: [rwa-vault, dashboard, moc]
updated: 2026-10-27
---
# 🛸 RWA Vault — Project Command Center

> **Single Source of Truth Dashboard** for Fahad and the Engineering Agents.  
> Status is derived from note frontmatter across `Questions/` and `Tasks/`. Zero duplicate status prose.

---

## 🎯 Quick Navigation
- **[[Project Modules To-Do (True Values)]]** — Verified code metrics and true completion percentages (M0–M11).
- **[[Agents/Protocol\|Agents Protocol & Master Prompt]]** — The 3-agent operating instructions and thread format.
- **[[_Templates/00 Vault Standard\|🔒 Vault Standard & Templates]]** — where every note goes and the locked templates for decisions, tasks, agent threads and concept notes.
- **[[Decisions Register]]** — every decision in the project, open and decided, in one table.
- **[[ADR Index]]** — Architecture Decision Records (0001–0026; only 0001 Accepted — see Q21).
- **[[Module 3 - Registry & Compliance/00 M3 Dashboard\|Module 3 Dashboard]]** — Current sprint command center.

---

## 🚦 Decision Radar

> Index only — every status below is read from the linked note's frontmatter. Full list: **[[Decisions Register]]**.

### ⏳ Open decisions for Fahad (2) — Module 3, Task 6
| Q | Question | Recommendation | Blocks |
|---|---|---|---|
| [[Module 3 - Registry & Compliance/Questions/Q21 - Accept the ADRs and settle the licence\|Q21]] | Accept the decided ADRs; licence | Accept all but 0017; GPL-3.0 | T7.3 |
| [[Module 3 - Registry & Compliance/Questions/Q22 - Who runs the T6.2 unaided onboarding rehearsal\|Q22]] | Who runs the unaided rehearsal? | A non-author teammate | T6.2, T7.4 |

### ✅ Decided
- **M3 Q01–Q16:** all decided 2026-10-27 — see [[Module 3 - Registry & Compliance/Decisions/Decisions Log|M3 Decisions Log]].
  **Q17 (2026-10-28):** 4 clauses and one custodian signer for MS1; insurer in Phase 2. **Q18 (2026-10-28):** clause 1 verified off-chain, hash anchored (ADR 0027). **Q19 (2026-10-28):** verify T6.0 → T6.2 protocol → build T1–T5 → T6.1a. **Q20 (2026-10-28):** local-only work pushed on the vault PR; PDF and PNGs restored.
- **Custody C1–C10:** settled; **C11** (production custodian) deferred — see [[Open Questions - Custody & Tokenisation]].
- **Latest audit:** [[2026-10-27 - Decision Conflict Audit]] (19 decision conflicts, 5 process conflicts, ADR ↔ code check).

---

## ⚡ Active Agent Work & Execution Lanes

| Task / Feature | Active Agent & State | Current File / Focus | Active Discussion Thread |
|---|---|---|---|
| **T0.6 AssetRegistry Interface** | ✅ Verified by Researcher | `IAssetRegistry.sol`, `AssetRegistryMock` clean | [[Module 3 - Registry & Compliance/Threads/Thread - T0.6 AssetRegistry Interface\|Thread T0.6]] |
| **T6.0 Onboarding Types & Schema** | 🧭 Awaiting Researcher VERIFY | Batch 2 applied on disk; `@rwa-vault/types` 32/32 green (2026-10-27) | [[Module 3 - Registry & Compliance/Threads/Thread - T6.0 Onboarding Schema & Parity\|Thread T6.0]] |
| **T0.7 Reserve Source Spec** | 🧭 Researcher planning | Specification note for `IReserveAttestationSource` | [[Module 3 - Registry & Compliance/Tasks/T0 - Interface PR\|Task T0]] |
| **T1.1 Vendor onchain-id** | ⌨️ Coder ready to execute | Git submodule `onchain-id` + solc 0.8.26 reconciler | [[Module 3 - Registry & Compliance/Tasks/T1 - Identity Layer\|Task T1]] |
| **T4.1 AssetRegistry FSM** | ⌨️ Coder ready to execute | UNREGISTERED → PENDING → LIVE → FROZEN | [[Module 3 - Registry & Compliance/Tasks/T4 - AssetRegistry & Admission\|Task T4]] |

---

## 📋 Open Actions for Fahad
1. Answer **Q21–Q22** above (each note has options and a recommendation).
2. Merge the vault-standardization PR (it now carries the local code work, Q20).

---

Up: [[Project Memory]] · Sub-Dashboards: [[Module 3 - Registry & Compliance/00 M3 Dashboard]]
