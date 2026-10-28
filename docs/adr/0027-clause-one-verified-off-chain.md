# ADR 0027 — For MS1, the custodian's ML-DSA-65 signature is verified off-chain and its envelope hash anchored

- **Status:** Proposed
- **Date:** 2026-10-28
- **Deciders:** Fahad Naseer
- **Answers:** Q18. **Depends on:** ADR 0011 (ETHFALCON pin), ADR 0013 (PQ guards the reserve), ADR 0015 (agent
  powers and key tiers), ADR 0017 (reserve source seam). **Read with:** Q17 (four clauses, one signer for MS1).

## Context

Clause 1 of the admission predicate requires a valid custodian signature on the reserve attestation. The custodian
signs with ML-DSA-65 (Tier 1, ADR 0013). The project has no Solidity ML-DSA-65 verifier: ADR 0011 pins a _Falcon_
verifier (`ZKNOX_falcon`, about 3.9M gas), and the Build Plan places the M2 verifier off-chain. `IReserveAttestationSource`
already leaves signature checking to the source's submit path rather than to the registry.

## Decision

For MS1, clause 1 is evaluated **off-chain**. The M2 verifier — or, until it exists, M1's native ML-DSA-65 verify via
`pqctl` — checks the custodian envelope. An allow-listed submitter, the Tier 1 service key (ADR 0015), then calls the
source's `submitAttestation` with the decoded fields and the envelope hash. M9 anchors the hash, so anyone can fetch the
original envelope and re-verify the signature offline against the custodian's registered key.

Clauses 2–4 stay on-chain in `AssetRegistry.admit`, unchanged.

## Consequences

**Good.** MS1 uses code that already works and stays off M2's critical path. The signature remains independently
checkable after the fact, which is the property the thesis claims.

**Costly, and to be disclosed.** On-chain, clause 1 is trusted to the submitter key: a compromised submitter could
record an attestation that no valid signature backs, detectable only by an offline re-check. The thesis and demo must
say so, alongside ADR 0017's disclosure that the reserve figure is asserted.

**Revisit trigger.** A pinned, conformance-tested Solidity ML-DSA-65 verifier with a measured gas cost, or ML-DSA
precompiles on the target chain. On-chain verification would then supersede this record behind the same seam.

## Alternatives considered

**On-chain ML-DSA-65 verifier.** Rejected for MS1: none is pinned, its gas cost is unmeasured and likely in the
millions, and the research would put the MS1 gate at risk. Named as future work.

**Custodian signs with Falcon-512 so ETHFALCON can verify on-chain.** Rejected: it reopens M2's key-tier design and
ADR 0013, and moves the custodian onto the device-key algorithm.
