# ADR 0025 — M3 contracts are immutable: plain deploys, no proxies

- **Status:** Accepted (2026-10-28, Q21)
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer
- **Answers:** Q15. **Depends on:** ADR 0012 (hybrid ERC-3643), ADR 0015 (agent powers and key tiers)

## Context

Nothing had decided whether M3's contracts are upgradeable, and that silence was the problem
rather than either answer.

Tokeny's upstream T-REX is proxy-based, with an implementation authority. ADR 0012 has us
vendoring part of that stack — `onchain-id` — while building the token, the registries,
ModularCompliance and the AssetRegistry ourselves. Without a decision, the vendored half
would arrive proxy-shaped and the built half would be plain deploys, and the project would
have a mixed upgradeability model that nobody chose and no document explains.

## Decision

**M3's own contracts are immutable.** Plain deployments, constructors rather than
initializers, no proxy, no storage gaps, no implementation authority of our own.

Vendored `onchain-id` contracts are used as upstream ships them; where upstream is
proxy-based that is a property of the vendored code, not an upgrade path we operate.

## Rationale

The realistic changes are already configurable without an upgrade. `setAttestationSource`
swaps the reserve source when M5 replaces the MS1 stub (ADR 0017). `setValuationWindow` and
`setValuationWindowFor` change τ (ADR 0018). `setTokenFor`, `addAgent` and `removeAgent`
cover the wiring and the roles. The registry was designed with these seams precisely so that
the expected changes are transactions rather than redeployments.

Against that, a proxy adds an upgrade key that can rewrite the admission predicate and the
compliance rules after investors hold tokens. That key is a permanent audit finding and a
centralisation question at the defence — and it sits awkwardly beside a project whose claim
is that the backing is verifiable rather than trusted. Published ERC-3643 audit guidance
already asks for every owner and agent address to be recorded as multisig-or-single-key;
adding an upgrade authority on top enlarges exactly the surface ADR 0015 works to constrain.

The cost is real and accepted: a bug in the admission predicate means a new deployment and a
migration, not a patch.

This record exists because "we never decided" is the worst available answer to the question
at a viva, and because without it ADR 0012's vendoring would have settled the matter by
accident.

## Consequences

**Good.** No upgrade key to govern, disclose or defend. Constructors can take and validate
their parameters, so a deployment cannot exist in a half-configured state — T4.1's
constructor takes the valuation window for exactly this reason.

**Costly.** A logic defect found after launch requires redeployment and holder migration.
This raises the stakes on T7's acceptance suite and on the invariant test, which are now the
main defence rather than one of two.

**Constrains.** T4.1 uses constructors, not initializers, and declares no storage gaps.
T5.1's deploy script wires a fresh deployment rather than pointing a proxy at an
implementation.
