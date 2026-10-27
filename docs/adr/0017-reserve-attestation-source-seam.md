# ADR 0017 — Reserve data reaches M3 through a stubbed interface seam

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

The AssetRegistry admission predicate has four clauses, and a gold lot may only reach LIVE
if all four hold: the custodian signature is valid, the sequence number is increasing, the
reserve is at least the intended supply, and the valuation is fresh.

The first two clauses M3 can evaluate alone. The third and fourth need data M3 does not
produce — how much metal the custodian holds, and when it was last valued. That data is the
output of Module 5 (Oracle & Proof-of-Reserve).

The schedule makes this a problem rather than a dependency. M3 is a Phase 1 module due in
Sprint 3; M5 is Phase 2, Sprints 4–5. The MS1 gate at week 6 requires "a gold lot registered
and tokenised **against an attested reserve**", so the clauses cannot simply be omitted,
and M3 cannot wait for its producer.

## Decision

M3 consumes reserve data through an interface it defines itself, `IReserveAttestationSource`,
exposing the reserve amount and the valuation timestamp that clauses three and four need.
For MS1 the interface is satisfied directly from a signed custodian envelope. In Phase 2, M5
implements the same interface and is swapped in, with no change to AssetRegistry.

We state explicitly, in the demo narration and in the thesis, that the MS1 reserve figure is
**asserted by the custodian, not independently verified**, and that what Module 3
contributes is the mechanism making that assertion tamper-evident, sequence-ordered and
publicly checkable — not evidence that the metal exists.

## Consequences

**Good.** M3 stays self-contained and MS1 stays reachable without faking the predicate: all
four clauses genuinely execute, against a real signed envelope. The interface is not
throwaway scaffolding — it becomes M5's specification, so the work is spent once. It also
matches the pattern used twice already in this module: ADR 0014 puts custom rules behind
`IModule`, ADR 0012 puts identity behind `IIdentity`.

**Costly, and this is the honest cost.** At MS1 the reserve number is supplied and signed by
the same party that benefits from it, and under the project's current custody plan that party
is the team itself. The signature proves the message was not altered in transit; it proves
nothing about gold. A reserve of any size could be asserted and the system would accept it
and mint against it, with the `attestedSupply ≤ reserveAmount` invariant holding perfectly
because both sides of the comparison came from the same source. Every real tokenised-gold
product shares this structure — PAXG's reserves rest on an attestation too — the difference
being that theirs is signed by a supervised third-party auditor and ours is not.

**Harder.** The project now carries a disclosure obligation. Presenting this as
"proof of reserve" without stating the limitation invites the question "what stops you
writing any number?", to which there is no answer. Stated up front, the limitation is
unremarkable and the mechanism is still a contribution.

**Opens a better option.** Because the trust gap is about *who asserts*, not about what the
chain can check, the natural strengthening is to require more than one asserting party with
opposing incentives — a custodian gains from overstating reserves, an insurer underwriting
that bullion loses money if they are overstated. That is recorded as open question Q11 and
would supersede the single-signer assumption here rather than this record's seam.

## Alternatives considered

**Block M3 on M5.** Rejected. It is the dependency-correct order and it would give a real
reserve figure, but it moves a Phase 1 module into Phase 2, leaves Sprint 3 with nothing to
deliver, and forfeits the MS1 gate.

**Hard-code reserve values as constants for the demo.** Rejected: it would make the third and
fourth clauses decorative, so the admission predicate the thesis describes would not be the
one that ran, and there would be no interface for M5 to satisfy later.

**Omit clauses three and four until M5 exists.** Rejected for the same reason, and because
the invariant `attestedSupply ≤ reserveAmount` is the registry's central safety property —
shipping the module without it would leave nothing to invariant-test in T4.5.
