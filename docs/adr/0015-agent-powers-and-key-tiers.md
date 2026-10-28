# ADR 0015 — Agent powers are mandatory, so they are governed: roles mapped to the PQ key tiers

- **Status:** Accepted (2026-10-28, Q21)
- **Date:** 2026-10-27
- **Deciders:** Fahad Naseer

## Context

ERC-3643 is not a trustless token standard, and it does not pretend to be. The spec
defines an `owner` role (ERC-173) that appoints and removes agents, and it **requires**
both a recovery system for investors who lose their keys and the ability for agents to
force transfers. `freeze`, `forcedTransfer` and `recoveryAddress` are therefore not
features we may decline; declining them would forfeit conformance, and with it the
decisions recorded in ADR 0012 and ADR 0016.

This sits awkwardly against the project's intent to be non-custodial. The resolution is
that non-custodiality is not delivered by removing agent powers — it is delivered by the
operator never holding investor tokens and the investor holding their own keys (questions
C2 and C4 in the custody question set). Agent powers remain, and the honest design question
is what governs them. Published ERC-3643 audit guidance treats them as a known
centralisation finding: it asks that every owner and agent address be recorded as
multisig-or-single-key, that agent powers be constrained by multisig or contract-level
access control, that ownership transfer use a two-step handoff or multisig, and that
`setIdentityRegistry` and `setCompliance` sit behind a multisig or timelock, since either
call replaces the token's entire trust basis in one transaction. The original T-REX
whitepaper notes an issuer may appoint itself sole registry agent to retain full control —
precisely the single-key pattern the checklists warn against.

Separately, Module 2 defines a three-tier key hierarchy: Tier 0 (SLH-DSA root, offline),
Tier 1 (ML-DSA-65 service), Tier 2 (Falcon device). The on-chain roles need to map onto it,
even where enforcement is procedural for the FYP.

## Decision

We implement `forcedTransfer`, `burn` and `recoveryAddress`, with targeted unit tests, and
we keep all three off the MS1 demo path.

We map the roles onto the key tiers as follows:

| On-chain role                      | Key tier            | Form                                                   |
| ---------------------------------- | ------------------- | ------------------------------------------------------ |
| `owner` (configuration)            | Tier 0/1 governance | **2-of-3 multisig**, not a single service key          |
| `agent` (operations: mint, freeze) | Tier 1 service key  | Single service key, acceptable for operational latency |
| Investor wallets                   | Tier 2 device keys  | Self-custodied                                         |

`setIdentityRegistry` and `setCompliance` are owner-only and therefore behind the multisig.
`forcedTransfer` additionally requires a timelock and emits a typed reason code before
execution. `freeze` stays on the fast path with the Tier 1 agent key, because incident
response needs it to be fast, whereas seizure does not.

Enforcement of the tier mapping is procedural for the FYP — the multisig is on-chain, but
the claim that its signers are Tier 0/1 custodians is documentation, not cryptography.

## Consequences

**Good.** The project's most predictable examiner question — "who can take my tokens?" —
has a cited, designed answer rather than a shrug. The timelock plus reason code turns an
unaccountable power into a publicly auditable one, which is a defensible thesis position
and costs little. The mapping also gives the deploy script a definition of role assignment
instead of leaving it to whichever key ran the deployment.

**Costly.** A multisig contract and a `forcedTransfer` timelock wrapper are extra contracts
with extra tests, and every owner-level configuration change in the demo now needs two
signatures, which makes rehearsal slower. Roughly two days of work.

**Harder.** The demo script must hold multiple keys, and a forced-transfer demonstration
can no longer be performed inline — it has to be queued ahead of time or shown as a test.
This is one reason these powers are excluded from the MS1 path.

**Honest about its limits.** Tier binding is social. An examiner who presses on whether the
multisig signers really hold Tier 0 keys will find documentation, not an on-chain proof.
On-chain PQ-gated administration is the named future-work item.

## Alternatives considered

**A single agent EOA holding every power.** Rejected: it is the pattern the audit
checklists specifically flag, and it would make the non-custodial framing indefensible.

**Multisig on everything, including `freeze`.** Rejected: freeze is the incident-response
tool, and requiring a second signature during an incident trades real safety for the
appearance of governance. Seizure is the power that benefits from delay, so the controls
are split by power rather than applied uniformly.

**Omitting `forcedTransfer` and `recoveryAddress` to claim full non-custodiality.**
Rejected because the spec mandates them, so this would be non-conformance, not
decentralisation — and it would leave an investor who loses a key with no recovery path at
all, which is worse for the user the claim is supposed to protect.
