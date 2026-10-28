---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q05
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q5 — Where does reserve amount + valuation freshness come from in M3, before M5 exists?
**Why it matters:** two of the four admission clauses (reserve ≥ supply, valuation fresh) need reserve data that the **M5 Oracle/Proof-of-Reserve** produces — and M5 is Phase 2, not built. If M3 waits for M5 it cannot finish in Sprint 3.
- **Option A — Stub the reserve source now behind an interface (`IReserveAttestationSource`); feed it a signed custodian attestation directly in M3; swap in M5 later.** Keeps M3 self-contained and MS1-reachable. Recommended.
- **Option B — Block M3 on M5.** Correct dependency-wise but breaks the phase plan (M3 is Phase 1, M5 is Phase 2).
- **Recommendation:** **Option A** — define the interface M5 will later satisfy, drive it from a custodian envelope for the demo. Record the seam in an ADR.
- **Blocks:** admission predicate impl, the demo data flow, the MS1 gate.
- `Decision:` **Option A** — stub the reserve source behind `IReserveAttestationSource`, driven by a signed custodian envelope for MS1; M5 implements the same interface in Phase 2. The MS1 reserve figure is therefore *asserted, not independently verified*, and the demo and thesis must say so. ADR `0017`. **Follow-on: see Q11**, which adds an insurer co-signature so the assertion rests on two parties with opposing incentives. _(Fahad Naseer, 2026-10-27)_