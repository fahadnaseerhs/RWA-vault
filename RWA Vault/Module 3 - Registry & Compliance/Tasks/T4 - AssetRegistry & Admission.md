---
tags: [rwa-vault, m3, task]
type: task
id: M3-T4
status: ready
agent: coder
progress: 0/6
unblocked_by: ["Q04=A", "Q05=A", "Q11=B", "Q13=A", "Q14=B", "Q15=A"]
updated: 2026-10-27
---
# 📋 Task Group T4 — AssetRegistry & Admission Predicate

> **Decisions Applied:** Q13=A ($\tau = 24$h default for gold, configurable, ADR 0018), Q14=B (Under-reserve emits event & blocks mints, ADR 0019), Q15=A (Immutable plain deploys, ADR 0025), Q11=B (Insurer co-signs 2-of-2 multisig attestation).  
> **Status:** Unblocked. T4.1 can begin immediately.

### Critical Invariants & Rules
- **Q13 Test Rule:** 24 hours is the deployed default set via `setValuationWindowFor`. Boundary tests MUST set a short window ($\le 1$ hour) and assert against the configured value. Never hardcode 24h in predicate code!
- **Q11 Gas Check Pre-requisite:** Before writing the on-chain ML-DSA-65 verifier in T4.4, benchmark gas cost for 2 signatures.

### Subtasks Checklist
- [ ] **T4.1** `AssetRegistry.sol` implementing `IAssetRegistry.sol`: State machine `UNREGISTERED` → `PENDING` → `LIVE` → `FROZEN`.
- [ ] **T4.2** 5-clause admission predicate ($SigValid$, $Seq$, $Reserve \ge Supply$, $Freshness \le \tau$, $PolicyValid$).
- [ ] **T4.3** Connect `IReserveAttestationSource` stub driven by custodian envelope for MS1 (ADR 0017).
- [ ] **T4.4** Verify ML-DSA-65 envelope verification path.
- [ ] **T4.5** Foundry invariant test: `attestedSupply <= reserveAmount` on every mint and attestation.
- [ ] **T4.6** State-transition unit tests covering rejections, freezes, and unfreezes.

Up: [[M3 Task Board and Todo]]
