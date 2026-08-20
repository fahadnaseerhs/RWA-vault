# ADR 0002 — The PQ primitive inventory is six, and M1 owns all six

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

The M1 build plan requires the conformance harness to run "against both native and
WASM builds, all six primitives", and RQ1 asks for keygen/sign/verify latency and
key/signature sizes "for all six primitives, native and in browser WASM". But
`packages/pq-core/src/index.ts` exports exactly four algorithm identifiers, and the
M1 manual's §5.5 flags the mismatch as a specification issue that must be closed
before the test matrix is frozen — explicitly warning that four must not be reported
as six.

The mismatch is resolvable from the proposal rather than by negotiation. Table 2
("Primitive assignment — every post-quantum operation in the system is one row of
this table") lists seven rows over six _distinct_ primitives:

| Row | Actor           | Primitive                       |
| --- | --------------- | ------------------------------- |
| 1   | User device     | Falcon-512                      |
| 2   | Custodian       | ML-DSA-65                       |
| 3   | Oracle          | ML-DSA-44                       |
| 4   | Administration  | ML-DSA-65 (same primitive as 2) |
| 5   | Root of trust   | SLH-DSA-SHA2-128s               |
| 6   | Confidentiality | ML-KEM-1024 (at rest)           |
| 7   | Confidentiality | ML-KEM-768 (in transit, hybrid) |

Deduplicating ML-DSA-65 across the custodian and administration roles gives six:
four signature schemes and two KEM parameter sets. "Six primitives" was never a
different count of signature algorithms — it is the signature set plus the two
confidentiality KEMs, which the TypeScript surface simply has not grown yet.

Table 5 corroborates this: boundary B6 is "service ML-KEM-768 mTLS", and §Model 7
states documents are "encrypted under ML-KEM-1024 wrapping … transported over hybrid
X25519 + ML-KEM-768". These are protocol primitives with the same conformance and
benchmark obligations as the signature schemes, and today no module owns them.

## Decision

**The inventory is six primitives: `falcon-512`, `ml-dsa-44`, `ml-dsa-65`,
`slh-dsa-sha2-128s`, `ml-kem-768`, `ml-kem-1024`.** M1 owns all six in the Rust
core, the conformance harness, and the benchmark harness. The build plan's "six"
and the package's "four" are both retained without either being restated: the
package grows by two identifiers.

M1's public surface is two APIs, not one, because a KEM is not a signature scheme:

- **Signature API** — `keygen` / `sign` / `verify` / `metadata`, over the four
  signature identifiers. Unchanged from the M1 manual §5.2 contract.
- **KEM API** — `kemKeygen` / `encapsulate` / `decapsulate` / `kemMetadata`, over
  the two ML-KEM identifiers.

Three exclusions are drawn deliberately:

1. **The X25519 + ML-KEM-768 hybrid combiner is not M1.** X25519 is a classical
   primitive, and a hybrid KEM is a _construction over_ primitives, with its own
   key-derivation and combiner-security argument. M1 supplies the ML-KEM-768 half
   as a primitive; the module owning service transport owns the combiner.
2. **Key storage, rotation, and role enforcement are not M1** (M2, per the existing
   scope boundary). M1 rejects algorithm/key _type_ mismatches; it does not know
   which actor is allowed to hold which key.
3. **Document encryption workflow is not M1.** M1 supplies encapsulate/decapsulate;
   the AEAD, the wrapping format, and the retention policy belong to the module that
   stores documents.

The M1 Definition of Done item "All four current algorithm IDs have reviewed
keygen/sign/verify implementations" is amended by this record to read: _all four
signature IDs have keygen/sign/verify and both KEM IDs have keygen/encapsulate/
decapsulate, in their required runtime targets._

Every M1 report — conformance, benchmark — states the inventory as
"6 primitives (4 signature, 2 KEM)" with the per-primitive rows visible, so the
count can be audited from the report rather than trusted.

## Consequences

**Good.** The build plan, the proposal's Table 2, RQ1 and the package now agree on
one number that is derivable from a cited source rather than asserted. The two KEMs
get conformance and benchmark evidence in the module built to produce exactly that
evidence, instead of arriving unmeasured inside a transport or document module at a
point in the schedule where there is no time to measure them.

**Good.** ML-KEM is the cheapest of the six to add: FIPS 203 is final, ACVP vectors
are the most complete of any PQC algorithm, and the implementation comes from the
same upstream and the same build as ML-DSA (ADR 0003). The marginal cost is far
below the cost of standing up a second cryptographic crate in a later sprint.

**Costly.** M1's API surface grows by a second shape. The `PqAlgorithm` union can no
longer be passed indiscriminately to `sign`, so the TypeScript types must split into
`PqSignatureAlgorithm` and `PqKemAlgorithm` with `PqAlgorithm` as their union. Every
switch that today claims exhaustiveness over four members must be revisited.

**Costly.** M1's critical path lengthens in the project's highest-risk module. This
is accepted because the two KEMs are additive rather than entangled: they share the
binding, the build, the RNG, the error type and the CI matrix already required for
the signature schemes, and they can be landed in Stage 2 after the signature vertical
slice has already proven the build.

**Requires follow-through.** `packages/pq-core/src/index.ts` must gain `ml-kem-768`
and `ml-kem-1024`, and `PQ_ALGORITHMS` must be split. This is a Stage 1 code change,
not a Stage 0 one, and is listed here so that it is not lost.

## Alternatives considered

**Declare "six" a drafting error and keep four.** Rejected: the proposal's Table 2
is the authority the build plan was written from, and it contains six distinct
primitives. Calling the count an error would require deleting two rows that the
system's confidentiality argument and trust-boundary table both depend on. It would
also leave ML-KEM unowned by any module, which is how a primitive reaches the
evaluation phase unmeasured.

**Keep four in M1, and put the two KEMs in the module that uses them.** Rejected on
two grounds. First, RQ1's measurement set is six and the benchmark harness is an M1
deliverable, so M1 would have to benchmark primitives it does not implement.
Second, it re-creates the exact problem M1 exists to prevent: "separate cryptographic
code in every application and service" (manual §3). The confidentiality primitives
would be bound, built, seeded and error-handled a second time by a different
developer under schedule pressure.

**Redefine "primitive" as an (algorithm, runtime target) cell to reach six.**
Rejected: it is arithmetic dressed as a decision. Four algorithms across two targets
is eight, not six, and no grouping of the four signature schemes produces six without
a contrived rule. This is precisely the "reporting four algorithms as six" that the
manual forbids.

**Count the four signature schemes plus two hash functions (Keccak-256, SHA-256).**
Rejected: hashes are not assigned actors in Table 2, are not post-quantum primitives
in the sense the table uses, and are not signed or benchmarked as protocol
primitives. The reading also fails against RQ1, which asks for _key generation_ and
_signature sizes_ per primitive — quantities a hash function does not have.
