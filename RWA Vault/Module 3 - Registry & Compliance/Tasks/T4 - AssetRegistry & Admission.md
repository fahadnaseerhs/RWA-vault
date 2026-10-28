---
tags: [rwa-vault, m3, task]
type: task
id: M3-T4
status: ready
agent: coder
progress: 0/6
unblocked_by: ["Q04=A", "Q05=A", "Q11=B", "Q13=A", "Q14=B", "Q15=A"]
spec: "[[Threads/Rounds/T4 - Researcher Rulings (round 1)]]"
updated: 2026-10-28
---
# 📋 Task Group T4 — AssetRegistry & Admission Predicate

> **Decisions Applied:** Q13=A ($\tau = 24$h default for gold, configurable, ADR 0018), Q14=B (Under-reserve emits event & blocks mints, ADR 0019), Q15=A (Immutable plain deploys, ADR 0025), Q17=B (**4 clauses, one custodian signer for MS1**; insurer 2-of-2 from Q11 is Phase 2; signature location open as [[Questions/Q18 - Where is the ML-DSA-65 signature checked for MS1|Q18]]).  
> **Status:** Unblocked. T4.1 can begin immediately.

### Critical Invariants & Rules
- **Q13 Test Rule:** 24 hours is the deployed default set via `setValuationWindowFor`. Boundary tests MUST set a short window ($\le 1$ hour) and assert against the configured value. Never hardcode 24h in predicate code!
- **Q17/Q18 pre-requisite:** no on-chain ML-DSA-65 verifier exists in the project (ADR 0011's ~3.9M gas is Falcon). T4.4 follows Q18 = A / ADR 0027: verify off-chain, Tier 1 submitter records result + envelope hash; the clause count is settled at four (Q17).

### Subtasks Checklist
- [ ] **T4.1** `AssetRegistry.sol` implementing `IAssetRegistry.sol`: State machine `UNREGISTERED` → `PENDING` → `LIVE` → `FROZEN`.
- [ ] **T4.2** Admission predicate: 4 clauses ($SigValid$, $Seq$, $Reserve \ge Supply$, $Freshness \le \tau$) per ADR 0017 (Q17=B). $PolicyValid$ is Phase 2.
- [ ] **T4.3** Connect `IReserveAttestationSource` stub driven by custodian envelope for MS1 (ADR 0017).
- [ ] **T4.4** Verify ML-DSA-65 envelope verification path.
- [ ] **T4.5** Foundry invariant test: `attestedSupply <= reserveAmount` on every mint and attestation.
- [ ] **T4.6** State-transition unit tests covering rejections, freezes, and unfreezes.

Up: [[M3 Task Board and Todo]] · Thread: [[Threads/Thread - T4 AssetRegistry & Admission]]
