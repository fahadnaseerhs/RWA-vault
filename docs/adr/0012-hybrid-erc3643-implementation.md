# ADR 0012 — Hybrid ERC-3643 implementation: vendor the identity layer, build the rest

- **Status:** Proposed
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

Module 3 needs a working ERC-3643 (T-REX) deployment: a permissioned token, an identity
registry with its storage, a claim topics registry, a trusted issuers registry, modular
compliance, and the ONCHAINID contracts (ERC-734 key management, ERC-735 claim holding)
that the registry verifies against. Commit `0b2dd0e` scaffolded the interfaces for all of
this but implemented none of it.

Two forces pull in opposite directions. The project is an FYP whose thesis has to claim a
contribution, and "we installed a library" is a weaker claim than "we implemented the
standard". Against that, ERC-3643's identity half is fiddly in a way that carries no
thesis value: ERC-734/735 key purposes, claim encoding, signature recovery and revocation
are easy to get subtly wrong and tedious to test, and getting them wrong undermines every
compliance guarantee above them.

A third force matters for credibility: ERC-3643 is a Final EIP with substantial
institutional adoption, and conformance to it is externally checkable. Conformance,
however, is a property of our contracts' behaviour, not of whose code we run — building
our own implementation does not make us non-standard.

Sprint 3 holds both M3 and M4, and M3's done-criterion ("a provider onboards a gold lot
unaided, and a direct-contract transfer that bypasses the API is refused") is a MS1 gate
dependency. Effort spent on the identity plumbing is effort not spent on the AssetRegistry,
which is the part nobody else has built.

## Decision

We take the hybrid path. We vendor Tokeny's `onchain-id` for the ERC-734/735 identity
contracts — `Identity` and `ClaimIssuer` — as a Foundry submodule, and we implement the
rest ourselves against the interfaces already scaffolded: the ERC-3643 `Token`, the
`IdentityRegistry` and `IdentityRegistryStorage`, the `ClaimTopicsRegistry`, the
`TrustedIssuersRegistry`, `ModularCompliance`, and the `AssetRegistry` with its admission
predicate.

The dividing line is deliberate: we vendor the part that is pure standards plumbing and
build the part that carries the project's contribution, including every seam where the
post-quantum attestation path meets the token.

## Consequences

**Good.** The claim-verification path we rely on for every compliance decision is audited
upstream code, so a bug there is not ours to find. The thesis can state precisely which
contracts we implemented and show the acceptance spec they pass. The AssetRegistry and its
compliance module — the novel part — get the time budget they need.

**Costly.** A third submodule enters the build, with its own Solidity version constraints
to reconcile against our `0.8.26` pin, and its GPL-3.0 licence propagates (already true of
the headers committed in `0b2dd0e`, so no new constraint in practice). We also inherit a
dependency whose upgrade cadence we do not control.

**Harder.** Two codebases now have to agree on the identity interface. If upstream's
`Identity` diverges from the `IIdentity` we scaffolded, the adapter work falls to us, and
the acceptance spec is where the mismatch will surface rather than at compile time.

**Reversible in one direction only.** Moving later from hybrid to fully in-house is a
contained piece of work (implement two contracts against an interface we already depend
on). Moving from hybrid to fully vendored would mean discarding our registries, so if the
schedule collapses the fallback is to vendor the full T-REX suite and document the change.

## Alternatives considered

**Option A — vendor the full Tokeny T-REX suite.** Rejected, though it was the starting
preference. It is the fastest and most audited route, but Tokeny's token and compliance
contracts do not bend readily to the AssetRegistry and PQ-attestation seam that is the
project's actual contribution, and it leaves the thesis with no implemented artefact in
Module 3 to examine.

**Option B — build all eight contracts in-house.** Rejected on risk, not on ambition. The
ERC-734/735 layer is the highest-effort, lowest-value part of the module, and a subtle
error in claim signature verification would silently void the compliance guarantees that
the acceptance spec is supposed to prove.

## Revisit trigger

If the vendored `onchain-id` cannot be made to compile against our Solidity pin without
patching, Option B becomes cheaper than maintaining a fork, and this record should be
superseded rather than edited.
