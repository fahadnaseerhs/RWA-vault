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
- **[[ADR Index]]** — Architecture Decision Records (0001–0026 locked).
- **[[Module 3 - Registry & Compliance/00 M3 Dashboard\|Module 3 Dashboard]]** — Current sprint command center.

---

## 🚦 Decision Radar (Decisions & Unlocked Paths)

### Module 3 Shaping Decisions (16 / 16 Decided ✅)
All 16 decisions have been taken by Fahad. **Zero blocking questions remain for M3 core.**
| Question | Title | Decision Taken | ADR | Unblocks |
|---|---|---|---|---|
| [[Module 3 - Registry & Compliance/Questions/Q01 - Implementation Strategy\|Q01]] | Build vs Vendor ERC-3643 | **Option C:** Hybrid (vendor onchain-id, build rest) | `0012` | T1–T6 |
| [[Module 3 - Registry & Compliance/Questions/Q02 - Claim Topics\|Q02]] | KYC Claim Topics | **Option A:** Single KYC topic | — | T1.3 |
| [[Module 3 - Registry & Compliance/Questions/Q03 - Claims & PQ Cryptography\|Q03]] | ECDSA vs PQ for Claims | **Option A:** Claims ECDSA; PQ for custodian reserve | `0013` | T1.4, T4.4 |
| [[Module 3 - Registry & Compliance/Questions/Q04 - Asset Liveness Enforcement\|Q04]] | Compliance Module vs Token Check | **Option A:** Compliance Module (`AssetLiveModule`) | `0014` | T2.2 |
| [[Module 3 - Registry & Compliance/Questions/Q05 - Reserve Seam Architecture\|Q05]] | Reserve Source Seam | **Option A:** Stubbed `IReserveAttestationSource` | `0017` | T0.7, T4.3 |
| [[Module 3 - Registry & Compliance/Questions/Q06 - Compliance Modules\|Q06]] | Transfer Restriction Scope | **Option A:** Only AssetLiveModule for MS1 | — | T2.3 |
| [[Module 3 - Registry & Compliance/Questions/Q07 - Key Tiers & Governance\|Q07]] | Role & Key Hierarchy Mapping | 2-of-3 multisig on `owner`, Tier 1 service key on `agent` | `0015` | T5.2 |
| [[Module 3 - Registry & Compliance/Questions/Q08 - Token Granularity\|Q08]] | One Token per Asset vs Multi-asset | **Option A:** One ERC-3643 token per asset | `0016` | T3.1 |
| [[Module 3 - Registry & Compliance/Questions/Q09 - Provider Console Type\|Q09]] | UI Console vs CLI Script | **Option B:** Ops Console UI, Foundry script first | `0026` | T6.1a, T6.1b |
| [[Module 3 - Registry & Compliance/Questions/Q10 - Agent Recovery Powers\|Q10]] | Forced Transfer & Recovery | Implement mandated functions; keep off MS1 demo path | `0015` | T3.3 |
| [[Module 3 - Registry & Compliance/Questions/Q11 - Insurer Co-Signer\|Q11]] | Insurer Co-Signature | **Option B:** Custodian + Insurer 2-of-2 multisig | *ADR needed* | T4.2, T4.4 |
| [[Module 3 - Registry & Compliance/Questions/Q12 - Console Operator\|Q12]] | Internal Operator vs Self-service | **Option (a):** Internal operator for MS1 | — | T6.1b |
| [[Module 3 - Registry & Compliance/Questions/Q13 - Valuation Freshness Window\|Q13]] | Value of $\tau$ | **Option A:** $\tau = 24$ hours (settable in contract) | `0018` | T4.2 |
| [[Module 3 - Registry & Compliance/Questions/Q14 - Downward Attestation\|Q14]] | Attestation < Minted Supply | **Option B:** Emit `UnderReserve`, block further mints | `0019` | T4.2, T4.5 |
| [[Module 3 - Registry & Compliance/Questions/Q15 - Upgradeability vs Immutability\|Q15]] | Proxy vs Immutable Deployments | **Option A:** Plain immutable deployments | `0025` | T0, T5 |
| [[Module 3 - Registry & Compliance/Questions/Q16 - Frozen Token Transfers\|Q16]] | FROZEN Token Transferability | **Option A:** Freezes minting only; transfers permitted | `0019` | T3.2, T4.1 |

### Custody Cross-Cutting Decisions (C1–C11)
- **Settled (10/11):** C1 (Simulated custodian), C2 (Operator never holds tokens), C3 (Governed agent powers), C4 (Self-custody EOA), C5 (1 Token = 1 fine gram, ADR 0020), C6 (Cash-settled redemption, ADR 0023), C7 (Zero platform fiat custody, ADR 0022), C8 (Fractional title to identified lot, ADR 0024), C9 (Stale reserve freezes minting only, ADR 0021), C10 (Non-custodial claim defended).
- **Deferred (1/11):** C11 (Production custodian selection — deferred by agreement).

---

## ⚡ Active Agent Work & Execution Lanes

| Task / Feature | Active Agent & State | Current File / Focus | Active Discussion Thread |
|---|---|---|---|
| **T0.6 AssetRegistry Interface** | ✅ Verified by Researcher | `IAssetRegistry.sol`, `AssetRegistryMock` clean | [[Module 3 - Registry & Compliance/Threads/Thread - T0.6 AssetRegistry Interface\|Thread T0.6]] |
| **T6.0 Onboarding Types & Schema** | 🐞 Debugger → ⌨️ Coder | Batch 2 parity fixes, Ajv devDependency approved | [[Module 3 - Registry & Compliance/Threads/Thread - T6.0 Onboarding Schema & Parity\|Thread T6.0]] |
| **T0.7 Reserve Source Spec** | 🧭 Researcher planning | Specification note for `IReserveAttestationSource` | [[Module 3 - Registry & Compliance/Tasks/T0 - Interface PR\|Task T0]] |
| **T1.1 Vendor onchain-id** | ⌨️ Coder ready to execute | Git submodule `onchain-id` + solc 0.8.26 reconciler | [[Module 3 - Registry & Compliance/Tasks/T1 - Identity Layer\|Task T1]] |
| **T4.1 AssetRegistry FSM** | ⌨️ Coder ready to execute | UNREGISTERED → PENDING → LIVE → FROZEN | [[Module 3 - Registry & Compliance/Tasks/T4 - AssetRegistry & Admission\|Task T4]] |

---

## 📋 Open Actions for Fahad
1. **Gas Check Sign-off for Q11:** Awaiting ML-DSA-65 on-chain gas calculation (2 signatures approx ~3.9M gas each) before committing to 2-of-2 on-chain verifier vs off-chain aggregator.
2. **Review T6.0 Batch 2 Rulings:** Ready for Coder implementation in `packages/types`.

---

Up: [[Project Memory]] · Sub-Dashboards: [[Module 3 - Registry & Compliance/00 M3 Dashboard]]
