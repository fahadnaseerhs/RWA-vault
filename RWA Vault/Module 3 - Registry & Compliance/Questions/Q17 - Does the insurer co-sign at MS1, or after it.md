---
type: decision
id: M3-Q17
module: M3
status: decided
raised_by: researcher
raised_on: 2026-10-27
blocks: [T4.2, T4.4, T6.1a, T8.2, T0.7]
recommendation: "B — four clauses and one custodian signer for MS1; the insurer 2-of-2 and the policy clause follow in Phase 2 under their own ADR"
decision: "B — 4 clauses, one custodian signer for MS1; insurer 2-of-2 + policy clause in Phase 2 under its own ADR"
decided_by: Fahad Naseer
decided_on: 2026-10-28
adr: "0017 (stands as written); the Phase 2 insurer ADR will supersede its single-signer assumption"
tags: [rwa-vault, decision, m3, task6]
updated: 2026-10-27
---
# Q17 — Does the insurer co-sign the reserve attestation at MS1, or after it?

**Why it matters (plain words):** [[Q11 - Is the insurer a required co-signer on the re|Q11]] chose custodian + insurer
2-of-2 with a fifth "policy covers the value" clause, but only *on condition of a gas check and M2 agreeing the envelope
schema*. Neither has happened, there is no ADR, and the contract interface (`IReserveAttestationSource`) carries one
signer and four clauses. Meanwhile AGENTS.md already calls five clauses a "locked invariant". The Coder cannot write
T4.2 while two documents say different things.

**Blocks:** T0.7 (seam spec), T4.2 (predicate), T4.4 (signature path), T6.1a step 3 (attestation submit), T8.2 ·
**Does not block:** T1, T2, T3, T4.1, T6.0, T6.2's protocol document

## Options
- **Option A — Keep Q11 as decided: 2-of-2 + 5th clause for MS1.** Write the ADR, add `insurer` signature and
  `policyCoverage`, `policyExpiry` to the attestation, an attestor registry, and the failure tests. *Cost:* 1–2 days plus
  M2 schema work, and the gas of a second ML-DSA-65 check (unknown — see [[Q18 - Where is the ML-DSA-65 signature checked for MS1|Q18]]).
  *Risk:* puts M2 on the MS1 critical path, which ADR 0013 and 0017 were written to avoid.
- **Option B — Four clauses and one custodian for MS1; insurer in Phase 2.** Q11 stays the target design. The T6.0
  schema already makes `attestations` an array, so adding the insurer later is additive. AGENTS.md and T4 are corrected
  to four clauses. *Cost:* none now. *Risk:* MS1's reserve rests on one signer, which ADR 0017 already discloses.
- **Option C — Insurer signs off-chain only for MS1.** Record the insurer signature in the envelope and check it in the
  off-chain verifier, not on-chain. *Cost:* small. *Risk:* a half-measure an examiner will see through.

## Recommendation
**Option B.** It removes the only decision that ties MS1 to an unbuilt M2 schema, and the seam (ADR 0017) and the array
schema make the Phase 2 upgrade an addition, not a rewrite.

## Decision
**Option B — four clauses and one custodian signer for MS1; the insurer 2-of-2 and the policy clause come in Phase 2 under their own ADR.** Q11 stays the target design. _(Fahad Naseer, 2026-10-28)_

Up: [[Open Questions for Fahad]] · Related: [[Q11 - Is the insurer a required co-signer on the re|Q11]], ADR `0017`, [[2026-10-27 - Decision Conflict Audit|Audit A1]]
