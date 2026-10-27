# ADR 0014 — Asset liveness is enforced by a compliance module, not by the token

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer
- **Partly superseded:** the phrase "vetoes any mint or transfer" below is narrowed by ADR 0019 §6 — the module
  vetoes **mints only**. The rest of this record stands.

## Context

Module 3 contains two checks that have nothing to do with each other. The ERC-3643 half
asks whether a *wallet* may hold tokens, answered from KYC claims on its ONCHAINID. The
AssetRegistry half asks whether a *gold lot* is in LIVE state with sufficient attested
reserve. The module's design question is where the second check physically executes.

ERC-3643 routes every transfer through `compliance.canTransfer(...)`, which fans out to
whatever modules the issuer has bound to its ModularCompliance contract. The official
documentation's own example modules — country allow and restrict lists, maximum balance per
holder, supply cap, time-window transfer limits, transfer fees, permit lists — are
described as developed by tokenization platforms and explicitly *not* part of the
open-source protocol. The extension point is the mechanism by which an issuer's private
rulebook reaches the token, and published audit guidance confirms the reference
implementation binds one token to exactly one compliance contract.

So the question is not whether a custom rule is legitimate. It is whether ours arrives
through the sanctioned seam or is welded into the token.

## Decision

Asset liveness is enforced by `AssetLiveModule`, a contract implementing `IModule`, bound
to the token's `ModularCompliance`. It reads `AssetRegistry` and vetoes any mint or
transfer for an asset that is not LIVE. The token itself never references an asset, an
assetId, or the registry; it knows only that compliance refused.

## Consequences

**Good.** The token remains a standard ERC-3643 implementation, which is what makes the
acceptance spec's six guarantees meaningful and keeps ADR 0012's "we implemented the
standard" claim honest. The custom rule becomes independently unit-testable: the module can
be exercised against a mock registry with no token in the picture. It is also removable and
replaceable at runtime through `ModularCompliance`, which is how a real issuer would stage
a rule change.

**Costly.** One more contract, one more binding step in the deploy script, and one more
indirection for a reader tracing why a transfer reverted. The veto surfaces as a compliance
failure rather than a named error, so the revert reason has to be deliberately informative
or debugging the demo becomes guesswork.

**Harder.** Module state and action hooks are now part of correctness. `AssetLiveModule` is
stateless, so this costs nothing today, but if a later module tracks anything across
transfers — holder counts, rolling volumes — the hook ordering becomes a correctness
concern rather than bookkeeping.

**Enables a near-free win.** Because the seam is now the official one, the official
`SupplyLimitModule` can be evaluated as a way to enforce `attestedSupply ≤ reserveAmount`
by driving its cap from each attestation, instead of hand-rolling that invariant (see Q6).

## Alternatives considered

**A direct `require(assetRegistry.isLive(assetId))` inside `Token.mint` and
`Token.transfer`.** Rejected. It is simpler to read, but it hard-wires the asset concept
into a contract the standard defines without one, it makes the token a modified ERC-3643
rather than a conformant one, and under ADR 0012's hybrid approach it would mean carrying a
patch against code we want to keep standard. It also forfeits runtime replaceability: a
rule change would become a token migration.
