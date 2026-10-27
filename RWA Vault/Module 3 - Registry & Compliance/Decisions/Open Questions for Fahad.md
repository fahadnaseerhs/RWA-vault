---
tags: [rwa-vault, m3, decisions, index]
status: all-sixteen-decided
updated: 2026-10-27
---
# 🎯 M3 Questions Index (All 16 Decided ✅)

> **Single Source of Truth:** Each question has its own dedicated note in `Module 3 - Registry & Compliance/Questions/`.  
> Status and decisions live inside each note's frontmatter. **Nothing in M3 core is decision-blocked.**

| # | Question Title | Decision Taken | ADR |
|---|---|---|---|
| [[Questions/Q01 - Build our own ONCHAINID + T-REX, or vendor To\|Q01]] | Implementation Strategy | Option C (Hybrid: vendor onchain-id, build rest) | `0012` |
| [[Questions/Q02 - Which claim topics make a wallet verified, an\|Q02]] | KYC Claim Topics | Option A (Single topic `KYC`) | — |
| [[Questions/Q03 - Who is the trusted claim issuer, and how does\|Q03]] | Claims vs Reserve Cryptography | Option A (Claims ECDSA, Reserve PQ ML-DSA-65) | `0013` |
| [[Questions/Q04 - Is asset is LIVE a Compliance Module, or a mi\|Q04]] | Asset Liveness Enforcement | Option A (ModularCompliance `AssetLiveModule`) | `0014` |
| [[Questions/Q05 - Where does reserve amount + valuation freshne\|Q05]] | Reserve Source Seam | Option A (Stubbed `IReserveAttestationSource`) | `0017` |
| [[Questions/Q06 - Which transfer-restriction compliance modules\|Q06]] | Transfer Restriction Scope | Option A (AssetLiveModule only for MS1) | — |
| [[Questions/Q07 - Map ERC-3643 owneragent roles onto the M2 thr\|Q07]] | Role & Key Hierarchy Mapping | 2-of-3 multisig on `owner`, Tier 1 service key on `agent` | `0015` |
| [[Questions/Q08 - One token per asset (TokenFactory), or a shar\|Q08]] | Token Granularity | Option A (One ERC-3643 token per asset) | `0016` |
| [[Questions/Q09 - What is the minimal provider console - real U\|Q09]] | Provider Console Surface | Option B (Ops console UI, Foundry script first) | `0026` |
| [[Questions/Q10 - Enable `forcedTransfer` `recoveryAddress` for\|Q10]] | Agent Recovery Powers | Implement mandated methods; keep off MS1 demo path | `0015` |
| [[Questions/Q11 - Is the insurer a required co-signer on the re\|Q11]] | Insurer Co-Signer | Option B (Custodian + Insurer 2-of-2 multisig attestation) | *ADR pending* |
| [[Questions/Q12 - Who operates the onboarding console the provi\|Q12]] | Console Operator | Option (a) (Internal operator for MS1) | — |
| [[Questions/Q13 - Valuation Freshness Window tau\|Q13]] | Freshness Window $\tau$ | Option A ($\tau = 24$ hours, configurable via setter) | `0018` |
| [[Questions/Q14 - What happens when a new attestation shows les\|Q14]] | Downward Attestation | Option B (Emit `UnderReserve`, block new mints) | `0019` |
| [[Questions/Q15 - Are M3's contracts upgradeable (proxy-based)\|Q15]] | Contract Upgradeability | Option A (Immutable plain deploys, no proxies) | `0025` |
| [[Questions/Q16 - May a holder transfer tokens of a FROZEN asse\|Q16]] | Frozen Token Transfers | Option A (Freeze blocks minting only; transfers continue) | `0019` |

Up: [[00 M3 Dashboard]] · Related: [[Decisions Log]], [[ADR Index]]
