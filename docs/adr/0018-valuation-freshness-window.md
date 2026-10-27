# ADR 0018 — The valuation freshness window is 24 hours, set rather than compiled

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer
- **Answers:** Q13. **Depends on:** ADR 0017 (reserve source seam), ADR 0019 (admission semantics)

## Context

Clause 4 of the admission predicate rejects an attestation whose valuation is older than τ.
The clause has existed since the predicate was written; τ's value never has. The maths note
flagged it explicitly — too large and stale valuations slip through, too small and honest
providers are refused because their custodian signs on a different schedule.

The interface exposes τ as an owner-settable, per-asset value (`valuationWindowOf`,
`setValuationWindow`, `setValuationWindowFor`), bounded above by `MAX_VALUATION_WINDOW` of
365 days. So the interface never needed the number. T4.2 and its boundary tests do.

## Decision

**τ = 24 hours for gold**, as the deployed default, set through the setters at deployment.

**τ is never a constant in the predicate.** The predicate reads the configured window.

**Tests set their own window.** A unit test cannot wait 24 hours, so T4.2's boundary tests
set a short window — one hour or less — through `setValuationWindowFor` and assert the
boundary behaviour against *whatever τ is configured*. **A test that hard-codes 24 hours is
wrong by construction.**

## Rationale

24 hours matches daily LBMA pricing and tolerates a custodian who signs once a day, in
another timezone, around a weekend. One hour — the M2 envelope's own validity — would force
near-real-time attestation from a human-operated vault, and the failure mode is an honest
bar refused at a demo.

The second half matters more than the number. A freshness window is exactly the kind of
parameter that gets compiled in "for now" and then cannot be changed without redeploying the
registry, which under ADR 0025's immutable deployment means migrating holders. Per-asset
configuration also anticipates the asset classes Q13 option C raised: gold revalues daily, a
REIT quarterly, and that difference is configuration rather than a new contract.

The test carve-out is recorded because it is the kind of constraint that evaporates between a
decision and a test suite. A boundary test written against a hard-coded 24 hours would either
be skipped, or quietly rewritten to assert something weaker, and the clause would ship
untested. Asserting against the configured value tests the mechanism rather than the number.

## Consequences

**Good.** Changing τ later is an owner transaction, not a code change. The boundary tests run
in milliseconds and still exercise the real comparison.

**Costly.** Two sources of truth in the tests — the configured window and the assertion — so
the tests must read the window back rather than assume it.

**Open.** Per-asset-class defaults (Q13 option C) are deliberately not set here. Only gold has
a number; another asset class gets one when it arrives.
