---
type: dashboard
tags: [rwa-vault, m3, decisions, index]
updated: 2026-10-27
---
# 🎯 M3 Questions Index

> Index only. Each question's status and answer live in its own note in `Questions/` (frontmatter `status`).
> Format: [[_Templates/Template - Decision|Template - Decision]]. Decided answers are listed in [[Decisions Log]].

## ⏳ Open — waiting on Fahad (raised 2026-10-27 for Task 6)

| # | Question | Recommendation | Blocks |
|---|---|---|---|
| [[Questions/Q20 - Push the local-only work to GitHub\|Q20]] | Push the local-only work; were the deleted files meant to go? | Push all, restore deletions | T0.8, T6.0 review |
| [[Questions/Q21 - Accept the ADRs and settle the licence\|Q21]] | Accept the decided ADRs; which licence? | Accept all but 0017; GPL-3.0 for contracts | T7.3 |
| [[Questions/Q22 - Who runs the T6.2 unaided onboarding rehearsal\|Q22]] | Who runs the unaided rehearsal? | A teammate who did not build T6 | T6.2, T7.4 |

## ✅ Decided

| # | Question | Decision | ADR |
|---|---|---|---|
| [[Questions/Q01 - Build our own ONCHAINID + T-REX, or vendor To\|Q01]] | Implementation strategy | C — hybrid: vendor `onchain-id`, build the rest | `0012` |
| [[Questions/Q02 - Which claim topics make a wallet verified, an\|Q02]] | Claim topics | A — single `KYC` topic | none (scope) |
| [[Questions/Q03 - Who is the trusted claim issuer, and how does\|Q03]] | Claims vs reserve cryptography | A — claims ECDSA, reserve ML-DSA-65 | `0013` |
| [[Questions/Q04 - Is asset is LIVE a Compliance Module, or a mi\|Q04]] | Asset liveness enforcement | A — `AssetLiveModule` in ModularCompliance | `0014` (§ transfer half superseded by `0019` §6) |
| [[Questions/Q05 - Where does reserve amount + valuation freshne\|Q05]] | Reserve source seam | A — stubbed `IReserveAttestationSource` | `0017` |
| [[Questions/Q06 - Which transfer-restriction compliance modules\|Q06]] | Transfer-restriction scope | A — AssetLiveModule only for MS1 | none (scope) |
| [[Questions/Q07 - Map ERC-3643 owneragent roles onto the M2 thr\|Q07]] | Role ↔ key-tier mapping | `owner` 2-of-3 multisig, `agent` Tier 1 key | `0015` |
| [[Questions/Q08 - One token per asset (TokenFactory), or a shar\|Q08]] | Token granularity | A — one token per asset | `0016` |
| [[Questions/Q09 - What is the minimal provider console — real U\|Q09]] | Provider console surface | B — ops-console UI, Foundry script first | `0026` |
| [[Questions/Q10 - Enable `forcedTransfer` `recoveryAddress` for\|Q10]] | Agent recovery powers | Implement; off the MS1 demo path; multisig + timelock | `0015` |
| [[Questions/Q11 - Is the insurer a required co-signer on the re\|Q11]] | Insurer co-signer | B — 2-of-2 + 5th clause, *conditional on gas + M2 schema* → MS1 scope reopened as **Q17** | none yet |
| [[Questions/Q12 - Who operates the onboarding console the provi\|Q12]] | Console operator | (a) internal operator for MS1 | none (scope) |
| [[Questions/Q13 - Valuation Freshness Window tau\|Q13]] | Freshness window τ | A — 24 h, set via setter; tests ≤ 1 h | `0018` |
| [[Questions/Q14 - What happens when a new attestation shows les\|Q14]] | Downward attestation | B — accept, emit `UnderReserve`, block mints | `0019` §3 |
| [[Questions/Q15 - Are M3's contracts upgradeable (proxy-based)\|Q15]] | Upgradeability | A — immutable plain deploys | `0025` |
| [[Questions/Q16 - May a holder transfer tokens of a FROZEN asse\|Q16]] | FROZEN token transfers | A — FROZEN blocks minting only | `0019` §6 |
| [[Questions/Q17 - Does the insurer co-sign at MS1, or after it\|Q17]] | Insurer co-sign at MS1? | B — 4 clauses + 1 custodian for MS1; insurer in Phase 2 (2026-10-28) | `0017` |
| [[Questions/Q18 - Where is the ML-DSA-65 signature checked for MS1\|Q18]] | Where clause 1 is checked | A — off-chain verify, Tier 1 submitter, anchored hash (2026-10-28) | `0027` |
| [[Questions/Q19 - What does the Coder do while T6 waits for T1-T5\|Q19]] | Task 6 order | A — verify T6.0 → T6.2 protocol → T1–T5 → T6.1a (2026-10-28) | none (sequencing) |

Cross-cutting custody decisions C1–C11: [[Open Questions - Custody & Tokenisation]]. All decisions in one place: [[Decisions Register]].

Up: [[00 M3 Dashboard]] · Related: [[Decisions Log]], [[ADR Index]]
