---
type: dashboard
tags: [rwa-vault, decisions, register, index]
updated: 2026-10-27
---
# 🗂️ Decisions Register — every decision in the project

> Index only. A decision's status and wording live in its own note (frontmatter `status`), and its reasoning in the ADR.
> Precedence when anything disagrees: **code → ADR → decision note → this register**. New decisions use
> [[_Templates/Template - Decision|Template - Decision]].

## ⏳ Open (0)
| ID | Question | Module | Recommendation | Note |
|---|---|---|---|---|

## ⏸️ Deferred (1)
| ID | Question | Note |
|---|---|---|
| C11 | Production custodian selection | [[Open Questions - Custody & Tokenisation]] |

## ✅ Decided
| ID | Decision | ADR |
|---|---|---|
| M1 Stage 0 | Six primitives; PQClean C + `slh-dsa`; WASM target; N-API + `pqctl`; byte contract; RNG; platforms; vectors; benchmarks; ETHFALCON pin | `0002`–`0011` |
| M3-Q01…Q16 | See [[Decisions Log|M3 Decisions Log]] (one row each) | `0012`–`0019`, `0025`, `0026` |
| M3-Q17 | 4 clauses + one custodian signer for MS1; insurer in Phase 2 (2026-10-28) — [[Q17 - Does the insurer co-sign at MS1, or after it]] | `0017` |
| M3-Q18 | Clause 1 verified off-chain for MS1; Tier 1 submitter; envelope hash anchored (2026-10-28) — [[Q18 - Where is the ML-DSA-65 signature checked for MS1]] | `0027` |
| M3-Q19 | Task 6 order: verify T6.0 → T6.2 protocol → T1–T5 → T6.1a (2026-10-28) — [[Q19 - What does the Coder do while T6 waits for T1-T5]] | none |
| M3-Q20 | Local-only work pushed; deleted PDF and PNGs restored (2026-10-28) — [[Q20 - Push the local-only work to GitHub]] | none |
| M3-Q21 | ADRs 0002–0027 Accepted; licence GPL-3.0 (2026-10-28) — [[Q21 - Accept the ADRs and settle the licence]] | `0001` |
| M3-Q22 | T6.2 tester: Hassan or Fawaz after T6.1a; outside tester for final MS1 run if time (2026-10-28) — [[Q22 - Who runs the T6.2 unaided onboarding rehearsal]] | none |
| C1 | Simulated custodian for the FYP | none |
| C2 | Operator never holds investor tokens | none |
| C3 | Agent powers governed (multisig, timelock) | `0015` |
| C4 | Investors self-custody (EOA) | none |
| C5 | 1 token = 1 **fine** gram, 18 decimals | `0020` |
| C6 | Redemption cash-settled; physical specified, not built | `0023` |
| C7 | Platform holds no money; fiat is an on-ramp seam | `0022` |
| C8 | Token = fractional title to an identified lot | `0024` |
| C9 | Stale reserve freezes minting only | `0021` |
| C10 | Non-custodial claim defended | none |

## 🔎 Audits
- [[2026-10-27 - Decision Conflict Audit]]

Up: [[00 Dashboard - Project Command Center]] · Related: [[ADR Index]], [[_Templates/00 Vault Standard]]
