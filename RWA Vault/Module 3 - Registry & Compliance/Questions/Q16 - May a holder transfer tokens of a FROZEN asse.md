---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q16
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q16 — May a holder transfer tokens of a FROZEN asset? ⭐ NEW
Found by the Debugger on T0.6 ([[T0.6 - IAssetRegistry Interface]] §18.4): **four of our own documents disagree**, and
T2.2 was about to hard-code one of them. ADR `0014` says the module vetoes "any mint **or transfer**" when the asset
is not LIVE; ADR `0021` says a stale reserve freezes **minting only**; the `freeze` documentation says "minting stops,
existing tokens remain"; `packages/types/src/index.ts` lists minting, redemption and borrowing.

**In plain words:** the custodian's valuation went stale, so we froze the gold lot. Can an investor who already holds
tokens still sell them to another verified investor — or are they stuck until we sort the custodian out?

- **Option A — FROZEN blocks minting only; transfers continue.** Holders keep their exit.
- **Option B — FROZEN blocks minting *and* transfers.** Nobody moves anything until the asset is live again.
- **Recommendation: A**, and I have ruled that way so T2.2 is not blocked (ADR `0019` decision 6, which supersedes
  `0014`'s "or transfer"). Reasons: the trigger for FROZEN is almost always the *custodian's* failure, so blocking
  transfers punishes holders for someone else's inaction and hands a third party a liveness switch; halting transfers
  already has its own mechanism in ERC-3643 (`pause` for the systemic case, per-wallet freeze for the targeted one), so
  making FROZEN do it as well duplicates `pause` and removes the operator's ability to distinguish a reserve problem
  from a security incident; and minting is the only action that increases the claim on the reserve.
- **Your call to overrule.** This decides whether investors can exit a troubled asset, which is a holder-rights
  question, not a technical one.
- **Blocks:** nothing — T2.2 has one unambiguous rule to build. If you reverse it, the change is one condition in one
  module. But answer it before T2.2 is **verified**, or we ship a rule you did not choose.
- **⚠ Update 2026-10-27 — you may have already answered this.** Custody decision **C9 = A** (ADR `0021`) settles that a
  stale reserve attestation freezes **minting only**, with transfers, borrows, repays and withdrawals all continuing.
  That is the same rule as Option A above, reached independently on the staleness path, so Q16 is now **corroborated by
  a decision you have already taken** rather than genuinely open. Two caveats before ticking it: C9 was decided about
  *staleness*, whereas Q16 is about the `FROZEN` **state** however it was reached (including a legal hold or an
  incident), and holder-exit rights are the kind of thing worth affirming deliberately rather than inheriting. So the
  question stands, but the expected answer is now **A, consistent with C9**.
- `Decision:` **Leaning (c) confirmed as the direction, still formally deferred** — a dedicated bullion vault operator, with the insurer kept separate per Q11=B so the opposing-incentive argument survives. Revisit before the production-path chapter, not before MS1. _(Fahad Naseer, 2026-10-27)_

---

## Decision summary (fill as you go)
| Q | Topic | Recommended | Decision |
|---|-------|-------------|----------|
| 1 | Own vs vendor ERC-3643 | B (build minimal) | **C** — hybrid (vendor `onchain-id`) |
| 2 | Claim topics | B (KYC + country) | **A** — KYC only |
| 3 | Issuer ↔ PQ | A (ECDSA claims, PQ at reserve) | **A** — ECDSA claims, PQ at reserve |
| 4 | LIVE as module vs mint-check | A (compliance module) | **A** — `AssetLiveModule` |
| 5 | Reserve source pre-M5 | A (stub interface) | **A** — `IReserveAttestationSource` stub |
| 6 | Restriction modules | A (only is-LIVE) | **A** — only is-LIVE (+ maybe `SupplyLimitModule`) |
| 7 | Role ↔ key tier | suggested mapping | **Adopted + 2-of-3 multisig on `owner`** |
| 8 | One token per asset | A (per-asset + factory) | **A** — per-asset; factory deferred |
| 9 | Provider console | A (script/CLI) | **B** — ops-console page, script first |
| 10 | Forced transfer/recovery | implement, defer from demo | **Implement** (mandated); deferred from demo |
| **11** | Insurer co-signs the attestation | B (custodian + insurer, 2-of-2) | **B** — 2-of-2 via attestor registry; gas check first |
| **12** | Who operates the onboarding console | (a) internal operator tool for MS1 | **(a)** — internal operator tool |
| **13** | Value of τ (valuation freshness) | A — 24 h, owner-settable | **A** — 24 h deployed; tests use a short window |
| **14** | Re-attestation below current supply | B — accept, block mints, flag | **B** — accept, block mints, `UnderReserve` |
| **15** | Upgradeable (proxy) or immutable contracts | A — immutable for MS1 | ⛔ **OPEN** |
| **16** | Transfers allowed on a FROZEN asset | A — minting only; transfers continue | ⛔ **OPEN** (ruled A to unblock T2.2) |

**Four open, none blocking today's work.** T0.6, T0.7, T1 and T4.1 can all start now.
- **Q11** → T4.2 / T4.4 (the predicate's clause count)
- **Q12** → T6.1b's scope only
- **Q13, Q14** → **T4.2 and T4.5.** Both are needed *before the admission predicate is written*, not before the
  interface. T0.6 exposes `setValuationWindow` without needing τ's value, and `admit`'s revert behaviour is named in
  the interface without fixing the downward-attestation rule.

**Answer Q13 and Q14 together with Q11** — all three shape the same function (`admit`), so one sitting avoids
three rounds of rework on [[Mathematics - Admission Predicate and Invariants]].

Up: [[Module 3 - Registry & Compliance]] · Related: [[M3 Decisions Log]], [[Decision Algorithms - for Fahad]], [[Agents - Workflow]]