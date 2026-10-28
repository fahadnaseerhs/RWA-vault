---
tags: [rwa-vault, m3, tasks]
status: ready-to-code
updated: 2026-10-27
---
# M3 Task Board and Todo

Every M3 task, with checkboxes and its position in the [[Agents - Workflow|agent loop]]. A task is **checkmarked only when the Researcher confirms its acceptance criteria** — not when the Coder says "done."

**Agent-state legend:** 🧭 Researcher (planning) · ⌨️ Coder (implementing) · 🐞 Debugger (fixing) · ✅ Researcher-verified (done).
**Blocked-until:** several tasks need a [[Open Questions for Fahad]] answer first — marked `⛔Qn`.

**Progress: 0 / 8 task groups · interfaces scaffolded (T0 largely done).**

> **Decisions locked 2026-10-27 — all ten.** Q1=C (hybrid: vendor `onchain-id`, build the rest), Q2=A, Q3=A, Q4=A, Q5=A,
> Q6=A, Q7=mapping + 2-of-3 multisig on `owner`, Q8=A, Q9=B (ops-console UI, script first), Q10=implement
> (mandated by the spec) but off the MS1 path. ADRs `0012`–`0017`. **Nothing is decision-blocked.**
> One new question is open — **Q11, insurer as required co-signer** — which affects T4.2/T4.4 only.

---

## T0 — Interface PR ✅ (mostly done, commit `0b2dd0e`)
- [x] **T0.1** ERC-3643 token interface `IERC3643.sol`
- [x] **T0.2** Identity registry suite (`IIdentityRegistry`, `*Storage`, `IClaimTopicsRegistry`, `ITrustedIssuersRegistry`)
- [x] **T0.3** ONCHAINID interfaces (`IIdentity`, `IClaimIssuer`, `IERC734`, `IERC735`)
- [x] **T0.4** Modular compliance interfaces (`IModularCompliance`, `IModule`)
- [x] **T0.5** `abstract` acceptance spec `ERC3643Acceptance.t.sol` (6 guarantees)
- [x] **T0.6** ✅ **DONE (re-verified after the §15 NatSpec pass)** — 0 "token base units" remaining, the unit rule in all 3 places, 12/12 "Anyone may call.", fmt clean, 6/6. Previously: ✅ done — Researcher-verified after the Debugger's final gate, 2026-10-27.** The full loop, twice round: built → 4 Coder questions → ruled → Debugger sweep **reopened it** (the invariant had nowhere to be computed) → `assetOfToken` + 10 more rulings → a vacuous test guard found and replaced → final gate **clean**. `IAssetRegistry.sol` + `IReserveAttestationSource.sol` + `AssetRegistryInterface.t.sol` with `AssetRegistryMock`. **12 views · 3 agent · 7 owner · 11 events · 21 errors · 22 selectors**, 6/6, fmt clean, 0 collisions against 151 OZ errors / 186 selectors / 78 events. Gate (a) proved by **mutation on a scratch copy**, not by reading. ADR `0019` written. ➡ **T2.2, T3.1, T6.1a and T6.1b can all build against `AssetRegistryMock` now.**
- [ ] **T0.7** `IReserveAttestationSource.sol` interface — ✅ unblocked (Q5=A: the seam M5 later satisfies). [[T0.6 - IAssetRegistry Interface]] §5 fixes the **two signatures T0.6 needs to compile**; the full research note is still owed. **Next job, with T0.6.**
- [ ] **T0.8** Consumer sign-off (M4, M5, M9 owners) on the interfaces

## T1 — Identity layer (ONCHAINID + registries) ✅ unblocked (Q1=C, Q2=A)
- [ ] **T1.1** Vendor `onchain-id` as a submodule (Q1=C): `Identity` + `ClaimIssuer` from upstream, reconciled against our `0.8.26` pin and the scaffolded `IIdentity`
- [ ] **T1.2** ~~`ClaimIssuer`~~ — vendored with T1.1; write adapter tests only
- [ ] **T1.3** `ClaimTopicsRegistry` seeded with the single `KYC` topic (Q2=A)
- [ ] **T1.4** `TrustedIssuersRegistry` binding the ECDSA project KYC issuer to the `KYC` topic (Q3=A)
- [ ] **T1.5** `IdentityRegistryStorage` + `IdentityRegistry` with working `isVerified`
- [ ] **T1.6** Unit tests: verified/unverified wallets, revoked claim, wrong-issuer claim, country update

## T2 — Modular compliance ✅ unblocked (Q4=A, Q6=A)
- [ ] **T2.1** `ModularCompliance` base: bind token, add/remove modules, `canTransfer` fan-out
- [ ] **T2.2** `AssetLiveModule` (`IModule`): vetoes transfer/mint unless the asset is LIVE
- [ ] **T2.3** ~~showcase restriction module~~ — dropped (Q6=A). Instead: evaluate the official `SupplyLimitModule` for `attestedSupply ≤ reserveAmount`
- [ ] **T2.4** Unit tests per module + the fan-out veto logic

## T3 — ERC-3643 token ✅ unblocked (Q8=A, Q10=implement)
- [ ] **T3.1** `Token` implementing `IERC3643`: `mint`/`transfer` calling `isVerified` + `canTransfer`
- [ ] **T3.2** Freeze (full + partial) and pause
- [ ] **T3.3** `forcedTransfer`, `burn`, `recoveryAddress` — implement + unit-test, keep off the MS1 demo path; `forcedTransfer` behind multisig + timelock (ADR `0015`)
- [ ] **T3.4** Batch operations
- [ ] **T3.5** ~~`TokenFactory`~~ — deferred until a second asset enters the demo (Q8=A, ADR `0016`)
- [ ] **T3.6** Make `ERC3643Acceptance.t.sol`'s concrete subclass; all 6 guarantees pass

## T4 — AssetRegistry + admission predicate ✅ unblocked (Q4=A, Q5=A)
- [ ] **T4.1** `AssetRegistry` state machine UNREGISTERED→PENDING→LIVE→FROZEN
> **✅ Decisions in (2026-10-27):** Q13=A τ **24 h for gold** (ADR `0018`), Q14=B, Q11=B insurer co-signs 2-of-2, Q15=A **immutable** (ADR `0025`).
> ⚠ **Q13 test carve-out — carry into T4.2's acceptance criteria.** 24 h is the **deployed default, set via the setter**, never a constant in the predicate. A unit test cannot wait 24 h, so boundary tests **set a short window (≤ 1 h) through `setValuationWindowFor`** and assert against **whatever τ is configured**. **A test that hard-codes 24 h is wrong by construction** — that is why the setter exists.
> ⚠ **Q11 sequencing: MEASURE GAS BEFORE BUILDING.** If ML-DSA-65 verification runs on-chain, a second signature roughly doubles a cost ADR `0011` puts at ~3.9M gas. Measure, report the number, then build. Also needs M2's agreement on the envelope schema. Clause 1 becomes a threshold check and the predicate grows to **5 clauses**, so sequence Q11 **with** Q13/Q14, not after.
- [ ] **T4.2** The 4-clause admission predicate (sig valid, seq increasing, reserve ≥ supply, valuation fresh) — see [[Mathematics - Admission Predicate and Invariants]]. ⚠ **Q11 open:** if the insurer becomes a required co-signer this grows a 5th clause (policy coverage ≥ attested value, policy not expired) and clause 1 becomes a threshold check — cheaper to build once than to widen later
- [ ] **T4.3** Bind reserve data via `IReserveAttestationSource`, fed by a custodian envelope for MS1 (Q5=A, ADR `0017`)
- [ ] **T4.4** Verify the custodian ML-DSA-65 envelope (Q3=A puts PQ here and nowhere else; still depends on M2 verifier readiness)
- [ ] **T4.5** Invariant test `attestedSupply ≤ reserveAmount` on every mint + attestation
- [ ] **T4.6** State-transition unit tests incl. rejected admissions and freeze/unfreeze

## T5 — Wiring + deployment ✅ unblocked (Q7)
- [ ] **T5.1** Deploy script in `contracts/script/` wiring token ↔ registry ↔ storage ↔ topics ↔ issuers ↔ compliance ↔ asset-live module
- [ ] **T5.2** Role assignment per ADR `0015`: `owner` = 2-of-3 multisig (Tier 0/1), `agent` = Tier 1 service key; `setIdentityRegistry` / `setCompliance` behind the multisig
- [ ] **T5.3** Devnet deployment + a smoke script that onboards one gold lot and mints

## T6 — Provider onboarding console ✅ unblocked (Q9=B) · 🧭 **researched**
> **Research done 2026-10-27 → [[T6 - Provider Onboarding Console]]** (plan + acceptance criteria AC-1…AC-18).
> Researcher's call: T6 **splits**. Only **T6.0** goes to the [[Coder Agent]] now; T6.1a/T6.3/T6.1b are fully
> specified but queued behind **T5.1** (nothing to run a script against until the wiring exists). New **Q12**
> (who operates the console) affects T6.1b's scope only — not a blocker.
- [ ] **T6.0** 🐞 **batch 2 built 2026-10-27** (32/32 incl. the Debugger's four, Ajv parity harness committed; questions → [[T6.0 - Coder Questions for Researcher (round 2)]]) · was: answers round 2 complete → [[T6.0 - Researcher Answers (round 2)]]. All 7 Debugger questions ruled + 2 parity rulings. 7-item batch, 4 of which already have failing tests committed. Headlines: the shared validator gets **no warning channel** (two consumers would read a warning differently — warnings belong to the script's pre-flight); a future `valuationTs` is **rejected with the same rule as T0.6's D1.2**, so B13 and D1.2 are one bug class; `maxLength: 78` + an exact `BigInt` check rather than an unreviewable 78-digit regex; the `assetId` regex **tightens** (`gold-lot-001-` is a different asset that looks identical to a human); and the **Ajv parity harness gets committed** as a devDependency — "dependency-free" governs runtime deps, and a scratch harness is worth nothing by next week.
- [ ] **T6.1a** Onboarding **script** `contracts/script/OnboardAsset.s.sol` (Foundry, declarative JSON input, idempotent, named-error translation) — also the deploy/smoke path, and the fallback if the UI slips. AC-4…AC-8. ⏳ *after T5.1*
- [ ] **T6.1b** Wrap it as a page in `apps/ops-console` (Q9=B) — note this is **two** jobs: scaffold React 18 + Vite + viem (needs ADR `0018`) *then* the 4-step wizard. AC-9…AC-14. ⏳ *after T6.1a; scope depends on Q12*
- [ ] **T6.2** "Unaided onboarding" rehearsal — a non-author runs it end-to-end; protocol + `docs/reports/M3-onboarding-rehearsal.md`. AC-15, AC-16
- [ ] **T6.3** The bypass test `contracts/test/registry/BypassTest.t.sol`: direct-contract transfer **and** mint **and** asset-not-LIVE all refused on-chain, each with its exact named error. AC-17, AC-18 ⏳ *after T6.1a*

## T8 — Custodian attestation portal ⭐ NEW (gap, 2026-10-27)
> **Not covered by T6.** Raised by the custody session: C1 makes the custodian a role behind an interface, and
> **signing a reserve attestation is a different actor, a different key and a different screen** from T6's *provider*
> console. T6 onboards a lot; this signs for the metal. Nothing on any board covered it.
- [ ] **T8.1** 🧭 Research note: who the custodian is for MS1 (C1 = simulated), which key signs, and what the screen does
- [ ] **T8.2** The signing path — produce an ML-DSA-65 envelope and call the MS1 source's `submitAttestation(bytes)` (ties to T0.7 / T4.4)
- [ ] **T8.3** A second console surface, or a CLI first by the same logic as Q9 (script before UI)
- [ ] **T8.4** Key separation from the `agent` service key per ADR `0015` — the custodian is not an operator

## T7 — Acceptance + MS1 readiness
- [ ] **T7.1** Full Foundry suite green (`forge test`), including the invariant run
- [ ] **T7.2** Gas snapshot for mint/transfer/admission
- [ ] **T7.3** ADRs written for every Q-decision taken (see [[M3 Decisions Log]])
- [ ] **T7.4** MS1 dry-run: a gold lot registered **and tokenised** against an attested reserve

---

## Suggested order
**T0.6 + T0.7 → T1.1 (vendor `onchain-id`) → T1.3–T1.6 → T2 → T3 → T4 → T5 → T6 → T7**, with T4.1 (the
AssetRegistry state machine) running in parallel with T1 since every blocking decision is now settled.

## Critical-path decisions
**None outstanding.** Q1–Q10 were answered on 2026-10-27, so T0.6, T0.7, T1 and T4.1 can all start.
**Q11** (insurer co-signature) is open but non-blocking: it changes T4.2's clause count, so answer it before T4.2
is written if you want to avoid reworking the predicate.
**Q12** (who operates the onboarding console — internal operator tool vs provider self-service) is open and
non-blocking: it changes T6.1b's scope only. Raised by the T6 research; see [[T6 - Provider Onboarding Console]] §9.

## Research notes (Researcher → Coder handoffs)
| Task | Note | Status |
| ---- | ---- | ------ |
| **active** | **[[Coder Work Order - T0.6 then T6.0]]** | ⌨️ **the page the Coder works from** — running order, the five rules, both batches' finish lines, and what is explicitly not in scope |
| T6 | [[T6 - Provider Onboarding Console]] | 🧭 research complete (AC-1…AC-20); T6.1a/b + T6.3 queued behind T5.1 |
| T6.0 | [[T6.0 - Coder Questions for Researcher]] → [[T6.0 - Researcher Answers]] | ✅ answers applied: B6 union + B1 doc comment, 13/13 tests green |
| T6.0 | [[T6.0 - Debugger Brief]] → [[T6.0 - Debugger Questions]] | 🐞 **done** — all 4 predicted defects confirmed and given failing tests (⌨️). 7 questions are with 🧭. D1 parity holds |
| T6.0 | [[T6.0 - Debugger Questions]] → **[[T6.0 - Researcher Answers (round 2)]]** | 🐞 **batch 2 built, back for Debugger re-run + verification.** All 7 Q + 2 parity rulings. Debugger: 0 divergences across 80 cases; 4 defects with failing tests committed |
| T0.6 | [[T0.6 - IAssetRegistry Interface]] · [[T0.6 - Fix Spec (round 2)]] · [[T0.6 - Debugger Brief]] | ✅ **verified & checkmarked** after a clean final gate. Debugger §20 |

Up: [[Module 3 - Registry & Compliance]] · Related: [[Agents - Workflow]], [[Open Questions for Fahad]]
