# ADR 0019 — Asset admission and freeze semantics in the AssetRegistry

- **Status:** Accepted (2026-10-28, Q21)
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer
- **Supersedes nothing. Depends on:** ADR 0014 (liveness as a compliance module), ADR 0015
  (agent powers and key tiers), ADR 0016 (one token per asset), ADR 0017 (reserve source seam)
- **Read alongside:** ADR 0021 (a stale reserve attestation freezes minting only). The two
  agree and divide the cases between them: 0021 governs _staleness_ ("nobody has spoken
  lately"), this ADR governs a _reported shortfall_ ("we have been told it is short"), which
  0021 explicitly defers here. **One terminology hazard for readers:** 0021's phrase "freezes
  minting" means _blocks the mint_, not the `FROZEN` state — under decision 3 below an
  under-reserved asset stays `LIVE` and the mint is vetoed by the compliance module. Nothing
  in either ADR moves an asset to `FROZEN` without an operator.

## Context

The AssetRegistry state machine is specified in the maths note as four states and a set of
legal transitions, with the admission predicate's four clauses gating `PENDING → LIVE`. The
specification is precise about the clauses and deliberately silent about four behaviours
that only surface when the interface is written. Each silence is a place where an
implementer would otherwise guess, and two of them are decisions a reviewer will ask about.

The four gaps, in the order they arise:

1. The maths note writes the failure branch as `PENDING → UNREGISTERED/rejected`, which can
   be read as a failed admission _deleting_ the registration.
2. It does not say whether an asset already LIVE may receive a further attestation.
3. Its own corollary on a reserve figure that falls below the circulating supply says
   "decide which" and leaves three options open.
4. The freeze and unfreeze transitions are listed without saying who may perform them, and
   the project's TypeScript state documentation already said one thing while the interface
   research said another.

A fifth parameter, the freshness window τ of clause 4, is a number rather than a behaviour
and is tracked separately as Q13.

## Decision

**1. A failed admission reverts and the asset remains PENDING.** Nothing is written. The
sequence number is not advanced, the reserve is not recorded, and the registration survives.

**2. Re-attestation of a LIVE asset is permitted and keeps it LIVE.** The clauses are
evaluated against the asset's _current_ circulating supply, not the intended supply given at
first admission.

**3. An attestation whose reserve falls below the circulating supply is accepted, not
refused.** The registry records the lower figure, emits `UnderReserve(assetId, reserve,
attestedSupply)`, and blocks further minting — enforcement sitting in the compliance module
per ADR 0014. The asset is **not** frozen automatically; that remains an operator decision.
This is the subject of Q14, for which this is the recommended answer.

**4. Freeze and unfreeze carry asymmetric authority.** `freeze` is an `agent` function
(Tier 1 service key). `unfreeze` is an `owner` function (2-of-3 multisig). This aligns the
interface with the state documentation in `packages/types/src/index.ts`, which already
described `FROZEN → LIVE` as governance-only.

**6. A FROZEN asset blocks minting only. Transfers continue.** `AssetLiveModule` vetoes a
movement only when it is a mint (`from == address(0)`) and the asset is not LIVE. **This
supersedes ADR 0014's phrase "vetoes any mint or transfer" on the transfer half**; ADR 0014
otherwise stands unchanged, and its own decision — that liveness is enforced in a compliance
module rather than in the token — is untouched.

**5. The registry cross-checks the asset identity returned by the attestation source.**
`IReserveAttestationSource.ReserveAttestation` carries a `bytes32 assetId`, and `admit`
reverts `AssetIdMismatch(expected, fromAttestation)` when it does not match the asset being
admitted — even though the id is also the lookup key.

## Rationale

**On (1).** Deleting a registration on a failed admission punishes the honest case. The
most frequent admission failure is a stale or superseded envelope, submitted by a provider
who has done nothing wrong and whose remedy is to ask the custodian for a fresher one. If
the failure also erased the registration, that provider would re-enter metadata and pay gas
again for someone else's timing. A revert costs them one failed transaction and nothing else.

**On (2).** Reserve attestation is a repeating event, not a one-off: a custodian signs
periodically for as long as the asset exists. If only a PENDING asset could be attested, a
LIVE asset's reserve figure would freeze at its admission value and the freshness clause
would become unsatisfiable the moment τ elapsed. Evaluating against current rather than
intended supply matters because supply moves after admission — tokens are burned,
and a later attestation must be judged against what is actually outstanding.

**On (3).** This is the one with a real argument on each side.

Refusing the attestation (the maths note's option A) keeps the stored reserve at its
previous, higher value. That is worse than it first appears: the chain would continue to
publish a reserve figure the custodian has explicitly stopped claiming, and the protocol's
own records would be the last place to learn about a shortfall. An attestation exists to
transmit what the custodian now asserts; discarding the ones we dislike makes the mechanism
decorative.

Auto-freezing (option C) overcorrects. A freeze halts every holder's transfers, and the
trigger would be a single message from a single party. A custodian who mistyped a figure —
or who wished to cause trouble — could stop the asset without any human reviewing the claim.
That hands an outside party a denial-of-service switch over our own users.

Accepting the figure and blocking new mints keeps the ledger honest without conceding
control: the bad news is recorded and visible, no new exposure can be created against the
shortfall, and a human decides whether the right response is a freeze, a fresh attestation,
or an investigation of the custodian.

**On (4).** The two actions differ in risk, so they should differ in authority. Freezing is
the brake: its failure mode is an unnecessary halt, which is recoverable and visible, and it
needs to be fast — requiring a multisig to stop minting during an incident is how incidents
become losses. Unfreezing is the opposite: it resumes minting against a reserve that may
still be stale or disputed, and its failure mode is the creation of unbacked tokens. Making
the brake cheap and the release expensive is the standard asymmetry for exactly this reason,
and ADR 0015's key tiers already separate a service key from governance.

**On (6).** Four documents disagreed about this — ADR 0014 said "mint or transfer", ADR 0021
said minting only, the `freeze` documentation said minting only, and the TypeScript state
comment listed minting, redemption and borrowing. T2.2 was about to hard-code one of them.

The decision follows the reasoning ADR 0021 already accepted for staleness, applied to the
freeze state. The usual trigger for FROZEN is the custodian's failure, not the holder's: a
stale valuation or a reported shortfall is something done _to_ the people holding the token.
Blocking their transfers removes their only exit as a penalty for someone else's inaction,
which is a liveness cost imposed by a third party and precisely the centralisation vector
this project works to remove elsewhere.

Halting transfers also already has a mechanism. ERC-3643 provides a token-level `pause` for
the systemic case and a per-wallet freeze for the targeted one. Making asset-FROZEN stop
transfers as well duplicates `pause` while taking away the operator's ability to choose
between a reserve problem and a security incident — two situations that call for different
responses. Minting is the only action that increases the claim on the reserve, so blocking
exactly that is the minimal response to uncertainty about the reserve's size.

**On (5).** The cross-check costs one word comparison and guards the seam that ADR 0017
exists to create. Today the source and the registry are written together; in Phase 2 the
source is Module 5, written later, and a mapping keyed incorrectly there would silently
return another asset's reserve for an asset that then admits against it. The id is redundant
precisely while both sides are correct, which is the only time a consistency check ever
looks redundant.

## Consequences

**Good.** The four behaviours are now citable rather than inferred, which is what the
Debugger needs in order to stop guessing. The under-reserve path produces an on-chain event
an operator can alert on. The freeze asymmetry removes a plausible audit finding before it
is written.

**Costly.** `unfreeze` behind a 2-of-3 multisig means restoring a wrongly-frozen asset takes
two signatures and therefore real time; this should be stated in the operator runbook rather
than discovered during a demo. Carrying `assetId` in the attestation struct adds a word to a
returned struct for a check that passes every time in the happy path.

**Open.** The value of τ is Q13 and is not decided here; the interface exposes it as an
owner-settable, per-asset value so that choosing it later is configuration rather than code.
Decision (3) is the recommended answer to Q14 and should be confirmed before the predicate
is implemented in T4.2.

**Wider than M3 — updated 2026-10-27 against the settled custody set.**
`packages/types/src/index.ts` describes FROZEN as blocking "minting, redemption, or
borrowing". Two thirds of that is now resolved elsewhere, and both resolutions confirm
decision 6 rather than contradict it.

ADR 0021 (custody question C9) settles that a stale reserve attestation freezes **minting
only**, so borrowing continues by intent. The asymmetry is deliberate and worth restating
here because it is the first thing a reader challenges: minting is the only action that
increases the claim on the reserve, and "stale" — nobody has spoken lately — is treated
more leniently than "under-reserved" — we have been told it is short — which decision 3
above governs. The residual risk, recorded in 0021, is that credit continues against
unreconfirmed backing during a long custodian outage.

ADR 0023 (C6) makes redemption **cash-settled only**, with no on-chain redemption path in
the FYP, so the redemption third is moot for now. An `IRedemption` interface is still owed
so the design is on record.

What remains is a real obligation on **M7**: freezing an asset in M3 does not by itself
stop a loan, so M7 must read the asset state itself if it wants that behaviour. This belongs
in M7's research rather than being assumed.

## Alternatives considered

**Auto-freeze on under-reserve.** Rejected above: it gives a single external signer the
power to halt the asset.

**Refuse the under-reserve attestation.** Rejected above: it leaves the chain asserting a
reserve the custodian has withdrawn.

**`unfreeze` as an agent function.** Rejected. It is the release of a safety brake, and
pairing it with a Tier 1 service key would mean a single compromised service key could both
hide a problem and resume minting against it.

**Dropping `AssetIdMismatch` as unreachable.** Rejected. It is unreachable only while every
source implementation is correct, and the interface exists so that a source we have not
written yet can be substituted.
