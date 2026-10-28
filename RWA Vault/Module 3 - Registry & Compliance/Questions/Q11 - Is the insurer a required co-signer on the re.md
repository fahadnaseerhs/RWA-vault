---
tags: [rwa-vault, m3, question]
type: question
id: M3-Q11
status: decided
decided_by: Fahad Naseer
decided_on: 2026-10-27
---
## Q11 — Is the insurer a required co-signer on the reserve attestation? ⭐ NEW
**Why it matters:** nothing on-chain can verify that gold exists. What a contract *can* verify is that several
independent parties, with **opposing incentives**, all signed the same reserve statement. A custodian benefits from
over-reporting reserves (more tokens mintable); an **insurer underwriting that bullion loses money if the reserve is
overstated**. Requiring both signatures turns "trust our attestation" into "trust two parties who would have to
collude against their own interests". That is the real-world answer to "who guarantees the gold", and it is
implementable in the admission predicate.

It also adds a clause the predicate can genuinely check: **policy coverage ≥ attested value, and policy not expired.**

- **Option A — Custodian signature only** (what Q5's decision currently implies).
  *What we build:* nothing more. One signer, one envelope. Simplest, and the reserve figure rests entirely on one party.
- **Option B — Custodian + insurer, 2-of-2, with policy metadata.** The envelope carries policy number, coverage limit
  and expiry; the predicate gains a 5th clause checking coverage and expiry.
  *What we build:* a required-attestor registry (role → key), threshold verification in the admission predicate, the
  policy fields in the M2 envelope schema, fixtures for both signers, and tests for the failure cases (insurer missing,
  policy expired, coverage below attested value). Realistically **1–2 days, not one line** — and see the gas note below.
- **Option C — Generalised m-of-n attestor set.** Custodian, insurer, auditor, any future party, with a configurable
  threshold per asset class.
  *What we build:* B, plus per-asset threshold configuration and the governance to change it. More tests, more surface,
  and nothing in the FYP demo exercises the third signer.

- **Recommendation:** **Option B, implemented through a small attestor registry so that C is a configuration change
  later rather than a rewrite.** The coverage-and-expiry clause is the part worth having: it is a solvency check that a
  contract can actually perform, unlike "does the gold exist".
- **Caveats to decide with open eyes:**
  1. **The insurer is also simulated for the FYP.** A real underwriter will not countersign a student project, so both
     keys are ours and the collusion argument is architectural rather than demonstrated. Say so plainly.
  2. **Gas.** Each additional post-quantum signature verification is expensive — ADR `0011` puts the Falcon dispute
     verifier at ~3.9M gas. If ML-DSA-65 attestation verification happens on-chain, a second signer roughly doubles that
     cost and the budget needs checking before committing. If verification is off-chain with on-chain dispute, the cost
     is negligible and B is clearly worth it.
  3. It changes the **M2 envelope schema** (policy fields) and the **4-clause predicate becomes 5-clause**, so
     [[Mathematics - Admission Predicate and Invariants]] needs updating and M2's owner has to agree.
- **Blocks:** T4.2 (predicate shape), T4.4 (envelope verification), the M2 envelope schema, and the custody claim in
  [[Open Questions - Custody & Tokenisation|C10]].
- `Decision:` **Option B** — custodian + insurer, 2-of-2, with policy number, coverage limit and expiry in the envelope and a fifth admission clause checking coverage ≥ attested value and policy not expired. Built through a small attestor registry so Option C (m-of-n) becomes configuration later, not a rewrite. **Gas check first:** if ML-DSA-65 verification runs on-chain, a second signature roughly doubles a cost ADR `0011` puts at ~3.9M gas — confirm the budget before committing. Needs M2's agreement on the envelope schema. The insurer is simulated for the FYP, so the opposing-incentive argument is architectural, not demonstrated; say so. _(Fahad Naseer, 2026-10-27)_

---