# ADR 0013 — Investor claims stay ECDSA; post-quantum signatures guard the reserve

- **Status:** Accepted (2026-10-28, Q21)
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

The project's premise is post-quantum anchoring, so the natural instinct is to make every
signature in the system post-quantum. ERC-3643 resists that instinct in one specific place.

Investor eligibility in ERC-3643 is expressed as claims: a trusted issuer signs an
attestation about a wallet's ONCHAINID, and `IdentityRegistry.isVerified()` asks the
issuer contract to confirm the signature is genuine and unrevoked. That verification is
ECDSA, on-chain, and it is part of the standard's own interface surface.

Module 2 produces a different kind of artefact: ML-DSA-65 signed envelopes, verified
through our own verifier, carrying custodian statements about physical reserves. These are
two incompatible signature worlds meeting inside one module, and Module 3 has to decide
which world guards which claim.

The schedule constrains the choice. M2 is skeleton-only, and M3 is due in Sprint 3 against
a MS1 gate. Any design that puts M2's verifier on M3's critical path inherits M2's risk.

## Decision

Investor eligibility uses standard ECDSA ERC-3643 claims, issued by a single project KYC
issuer registered in the Trusted Issuers Registry. The post-quantum path is confined to
the custodian reserve attestation consumed by `AssetRegistry`: an ML-DSA-65 envelope,
verified via the Module 2 verifier, carrying the reserve amount and valuation that two of
the four admission clauses depend on.

Stated as a rule: **PQ guards statements about the asset; ECDSA guards statements about the
investor.**

## Consequences

**Good.** The claim-verification path stays exactly what the standard specifies, so the
`isVerified` behaviour the acceptance spec tests is conformant and comparable to every
other ERC-3643 deployment. The PQ work concentrates where it is genuinely novel — a
custodian whose reserve statements cannot be altered or silently backdated — which is also
the part of the system the thesis's evaluation chapter measures.

**Costly.** The system is not uniformly post-quantum, and the thesis has to say so plainly.
An examiner may reasonably ask why investor claims were left quantum-vulnerable; the answer
is that a forged KYC claim admits an ineligible holder, whereas a forged reserve attestation
breaks solvency for every holder, so the two are not equal in blast radius.

**Harder.** Two verification stacks now coexist in one module, and a reader of the code has
to know which is which. The AssetRegistry is the only place they meet, so that contract's
documentation carries the burden of explaining the boundary.

**Deferred, not foreclosed.** Nothing here prevents a later move to PQ-backed investor
claims. It would mean a non-standard claim path behind the same `IIdentity` interface, and
it is a legitimate future-work item once M2 is mature.

## Alternatives considered

**Investor claims also backed by a PQ envelope, verified before the on-chain claim is
accepted.** Rejected on two grounds. It would require a bespoke claim-acceptance path,
weakening the "we implemented ERC-3643" claim that ADR 0012 is built on; and it would place
M2's unfinished verifier directly on the MS1 critical path, where a delay in M2 becomes a
missed gate in M3.

**Defer the question until M2 is complete.** Rejected: M3 ships in Sprint 3 and M2 is a
Phase 1 module still at skeleton stage. Deciding late would leave the Trusted Issuers
Registry and the issuer key setup unspecified while T1 is being built.
