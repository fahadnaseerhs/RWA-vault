# ADR 0016 — One ERC-3643 token per asset, with shared identity storage

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

A gold lot and, later, a T-bill or a REIT share are different assets with different
reserves, valuations and lifecycles. Module 3 has to decide whether each gets its own token
contract or whether one contract carries many assets distinguished by an identifier.

ERC-3643 answers this by construction. The official `TREXFactory` deploys a complete suite
— token, registries, compliance — in a single transaction, where configuring the main
contracts by hand takes on the order of fifteen transactions. Published audit guidance notes
the reference implementation binds one token to one compliance contract, and recommends
confirming that holds. An ONCHAINID is deployed for the financial asset itself, while
investor identities are deployed once per investor and reused.

Not everything is duplicated, which matters for cost: `IdentityRegistryStorage` can serve
the verification of many tokens at once, and the Implementation Authority is shared to give
centralised versioning across all tokens deployed from it.

The project's own constraint: M3's done-criterion is that *a* provider onboards *a* gold lot
unaided, and the MS1 gate needs one lot registered and tokenised. Multi-asset onboarding is
a Phase 3 concern.

## Decision

One ERC-3643 token contract per asset. `IdentityRegistryStorage` is shared across assets, so
an investor verified once is verified for every asset. Compliance is bound one-to-one with
each token, per the reference implementation.

For MS1 we hand-deploy a single token for a single gold lot. `TokenFactory` (task T3.5) is
built only when a second asset enters the demo.

## Consequences

**Good.** Per-asset state stays naturally isolated: a freeze, a supply cap or a reserve
shortfall on one lot cannot touch another, and the `attestedSupply ≤ reserveAmount`
invariant is expressed per token where it is easiest to prove. Shared identity storage means
KYC work is not repeated per asset. The pattern matches what an examiner will find in every
production ERC-3643 deployment.

**Costly.** Each new asset is a full suite deployment, so onboarding is heavier than writing
a row into a multi-asset contract, and the ops console will eventually need to track a
growing set of addresses. Gas cost per asset is real but irrelevant on a devnet.

**Harder.** Any cross-asset feature — a portfolio view, collateral baskets spanning assets
in M7 — has to aggregate across contracts rather than query one. That is deferred work, but
M10 and M7 should expect it.

**Deferred.** Not building `TokenFactory` now means the first onboarding is a script against
a hand-deployed suite. If a second asset arrives, the factory is required before the
"unaided onboarding" criterion can be claimed for it, and this is the stated trigger.

## Alternatives considered

**A single multi-asset token with assets distinguished off-chain or by identifier.**
Rejected. It departs from the standard's one-token-one-compliance model, which would void
the conformance argument in ADR 0012 and make the acceptance spec's guarantees untestable as
written. It also couples unrelated assets' failure modes: one asset's freeze or cap bug
becomes every asset's.

**Build `TokenFactory` now, before a second asset exists.** Rejected on sequencing, not on
merit. The factory is the right end state and the task remains on the board; building it
before anything needs it spends Sprint 3 time that T1 and T4 need, for a capability the MS1
gate does not exercise.
