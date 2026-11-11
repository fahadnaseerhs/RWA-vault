---
type: decision
id: M3-Q25
module: M3
status: decided
raised_by: researcher
raised_on: 2026-11-11
blocks: [T1.4, T1.6, T5.2, T6.2]
recommendation: "A — a project-operated simulated KYC issuer, disclosed as simulated, matching C1's treatment of the custodian"
decision: "A"
decided_by: Fahad Naseer
decided_on: 2026-11-11
adr: "0030 (Reserved stub claimed 2026-11-11; full record owed)"
tags: [rwa-vault, decision, m3, task1]
updated: 2026-11-11
---
# Q25 — Who is the trusted ECDSA KYC issuer for MS1, and do we hold its key?

**Why it matters (plain words):** `TrustedIssuersRegistry` has to be seeded with a real address whose signature on a
KYC claim we will accept. That address *is* the KYC authority for the whole system — whoever holds its key decides who
may hold tokens. For MS1 nobody has said who that is, so T1.4 cannot be seeded and the T6.2 rehearsal has no verified
investor wallet to mint to.

**Why it is not already answered:** Q03 = A settled the *algorithm* and the *placement* — investor claims are ECDSA,
and post-quantum signatures appear only at the custodian reserve attestation. It never named the issuer or said who
custodies its key.

**On disk now:** `contracts/src/registry/interfaces/ITrustedIssuersRegistry.sol:28` →
`function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external;`. No implementation
and no issuer address anywhere in the repo.

**Blocks:** T1.4 (seeding the issuer), T1.6 (the verified/unverified test matrix needs a real issuer to sign), T5.2
(role assignment), T6.2 (the unaided rehearsal needs a verified investor) · **Does not block:** T1.1, T1.3, T1.5

## Options
- **Option A — A project-operated simulated KYC issuer.** We generate an ECDSA keypair, hold it as a Tier 1 service
  key, and sign claims ourselves. *Cost:* none. *Risk:* we are both the gatekeeper and the operator, so the
  independence a KYC authority normally provides is absent — which must be disclosed, not implied away.
- **Option B — A third-party KYC provider.** Real independence. *Cost:* commercial and legal onboarding, well beyond
  the FYP. *Risk:* puts MS1 behind an external party's timeline.
- **Option C — One of the three of us as a named human issuer**, signing with a personal key. *Cost:* none.
  *Risk:* ties a project credential to an individual's key, and reads worse at a viva than an honest simulation.

## Recommendation
**Option A**, and disclosed in the same words C1 uses for the simulated custodian. It is the only option that fits the
FYP, and consistency matters: we already simulate the custodian and disclose it, so simulating the KYC issuer and
disclosing it is the same honest position rather than a new concession.

**Two things that must be true if A is taken.** The issuer key must be a **separate address** from the registry's
`agent` and from the attestation submitter — the same reasoning as D3, since one stolen key should not both admit an
investor and move tokens. And the demo narration must not present KYC as independently verified, because an examiner
who asks "who did the KYC?" and hears "we did" after being told the system is trust-minimised will press exactly there.

## Decision
**Option A — a project-operated simulated KYC issuer, disclosed as simulated.** _(Fahad Naseer, 2026-11-11)_

Disclosed in the same words C1 uses for the simulated custodian. Consistency is the argument: we already simulate the custodian and say so, so simulating the KYC issuer and saying so is the same honest position rather than a new concession.

**Two conditions, both binding.** The issuer key is a **separate address** from the registry's `agent` and from the attestation submitter — D3's reasoning extended, since one stolen key must not both admit an investor and move tokens. And the demo narration must not present KYC as independently verified: an examiner who asks "who did the KYC?" and hears "we did", after being told the system is trust-minimised, will press exactly there.

Up: [[Decisions Log]] · Related: [[T1 - Identity Layer]], [[Q03 - Who is the trusted claim issuer, and how does]]
