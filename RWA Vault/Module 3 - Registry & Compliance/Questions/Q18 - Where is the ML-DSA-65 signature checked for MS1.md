---
type: decision
id: M3-Q18
module: M3
status: open
raised_by: researcher
raised_on: 2026-10-27
blocks: [T0.7, T4.4, T6.1a, T8.2]
recommendation: "A — off-chain M2 verifier checks the signature; an allow-listed submitter writes the result; the envelope hash is anchored so anyone can re-check offline"
decision: ""
decided_by: ""
decided_on: ""
adr: none
tags: [rwa-vault, decision, m3, task6]
updated: 2026-10-27
---
# Q18 — Where is the custodian's ML-DSA-65 signature (clause 1) actually checked for MS1?

**Why it matters (plain words):** clause 1 says "the custodian's signature is valid". `IReserveAttestationSource` says
the check happens "on the source at submit time", which reads as on-chain. But the project has **no Solidity ML-DSA-65
verifier**: ADR 0011 pins a *Falcon* verifier (`ZKNOX_falcon`, ~3.9M gas — the number Q11's gas note borrowed), and the
Build Plan makes the M2 verifier an off-chain NestJS service. Until this is decided, T4.4 and T6.1a step 3 have no design.

**Blocks:** T0.7, T4.4, T6.1a step 3, T8.2 · **Does not block:** T1–T3, T4.1–T4.3, T6.0

## Options
- **Option A — Off-chain verification, on-chain record.** The M2 verifier (or, until M2 exists, `pqctl verify` from M1)
  checks the ML-DSA-65 signature. An allow-listed submitter address (Tier 1 service key, ADR 0015) calls
  `submitAttestation` with the decoded fields and the envelope hash; M9 anchors the hash, so anyone can re-verify the
  original signature offline. *Cost:* small; M1 already verifies ML-DSA-65 natively. *Risk:* clause 1 is trusted to the
  submitter on-chain — must be stated in the thesis, like ADR 0017's disclosure.
- **Option B — On-chain ML-DSA-65 verifier.** Find, pin and gas-measure a Solidity ML-DSA-65 verifier (none is pinned
  today), new ADR. *Cost:* days of research plus an unknown, probably multi-million gas figure. *Risk:* high; MS1 slips.
- **Option C — Switch the custodian to Falcon-512** so the already-pinned ETHFALCON verifier checks it on-chain.
  *Cost:* changes M2's tier design (custodian is Tier 1 ML-DSA-65). *Risk:* reopens M2 key tiers and ADR 0013.

## Recommendation
**Option A** for MS1, with Option B named as future work. It uses code that already works (M1 native ML-DSA-65), keeps
MS1 off M2's critical path, and the anchored hash keeps clause 1 independently checkable.

## Decision
> _Empty until Fahad decides._

Up: [[Open Questions for Fahad]] · Related: ADR `0011`, ADR `0013`, ADR `0017`, [[2026-10-27 - Decision Conflict Audit|Audit A2]]
