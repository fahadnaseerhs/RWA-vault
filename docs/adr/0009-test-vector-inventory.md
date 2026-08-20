# ADR 0009 — Test-vector inventory and what "conformance" means per primitive

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

The Definition of Done says "All CAVP vectors pass in both native and WASM builds",
and §5.5 requires official NIST CAVP/ACVP vectors "where available" and
PQClean/liboqs known-answer tests "where a final NIST vector set is not applicable".
§7 requires us to identify the authoritative source per algorithm and operation, and
to determine what replaces official CAVP vectors when an algorithm is not covered.

The honest answer differs sharply by primitive, and the difference has to be written
down rather than averaged into a single claim:

- **ML-DSA-44/65, ML-KEM-768/1024, SLH-DSA-SHA2-128s** are final FIPS standards with
  published ACVP vector sets covering key generation, signature generation,
  signature verification, and encapsulation/decapsulation. Conformance here is
  genuine standards conformance.
- **Falcon-512 has no CAVP or ACVP vectors, and cannot have them**, because FIPS 206
  is still a draft as of August 2026. The only authoritative fixtures are the NIST
  Round 3 submission KATs. This is not a gap we can close by looking harder; it is a
  property of where the standard is.

So the Definition of Done phrase is, read literally, unachievable — not through any
shortfall in the work, but because it presumes a vector set that does not exist for
one of the six primitives. Left unaddressed, this ends one of two ways: the release
gate is failed forever, or somebody quietly redefines "CAVP" to mean "the tests we
ran". Both are worse than amending the wording now.

A second issue is practical. The ACVP sets are large — SLH-DSA `sigGen` in
particular — and committing tens of megabytes of JSON into a repository whose
`.gitattributes` already treats binaries carefully is a poor trade.

## Decision

### The approved inventory

**Source A — NIST ACVP.** `usnistgov/ACVP-Server`, pinned at release tag
**`v1.1.0.43`** (12 August 2026), files under `gen-val/json-files/`:

| Primitive         | Vector sets                                                                  |
| ----------------- | ---------------------------------------------------------------------------- |
| ML-DSA-44, -65    | `ML-DSA-keyGen-FIPS204`, `ML-DSA-sigGen-FIPS204`, `ML-DSA-sigVer-FIPS204`    |
| ML-KEM-768, -1024 | `ML-KEM-keyGen-FIPS203`, `ML-KEM-encapDecap-FIPS203`                         |
| SLH-DSA-SHA2-128s | `SLH-DSA-keyGen-FIPS205`, `SLH-DSA-sigGen-FIPS205`, `SLH-DSA-sigVer-FIPS205` |

Only the parameter sets in ADR 0002's inventory are extracted; the other test groups
in each file are skipped, and the runner reports how many groups it skipped so a
silently empty run is visible.

**Source B — NIST Round 3 submission KATs**, for Falcon-512 only:
`falcon512-KAT.req` / `falcon512-KAT.rsp` from the Round 3 submission package.
Reproducing these requires the NIST AES-CTR-DRBG and the attached-signature (`sm`)
form, so the runner includes a documented, separately tested adapter from that form
to M1's detached 666-byte signature (ADR 0006). The DRBG lives in the test tree only
(ADR 0007).

**Source C — upstream implementation KATs.** The `.rsp` fixtures shipped with the
vendored PQClean schemes, at the vendored commit. These are a build-correctness check
on our `build.rs` rather than a standards check, and are reported as such.

**Source D — differential oracle.** The `pqcrypto-*` dev-dependencies of ADR 0003,
asserted byte-identical to the vendored build on every Source A/B/C case.

**Source E — project golden vectors.** `packages/pq-core/vectors/project/v1/`
(ADR 0006), consumed by Rust, TypeScript, WASM and Foundry. These prove the four
consumers agree with each other; they prove nothing about standards conformance and
are reported separately.

**Source F — negative and malformed-input suites.** Written by us, not imported:
bit-flipped signatures, bit-flipped messages, wrong public key, wrong algorithm for
the key, every length one byte short and one byte long, empty inputs, all-zero keys,
and a message at the 1 MiB cap and one byte over. Each asserts the specific error
class or the specific `false`, not merely "did not succeed".

**Source G — cross-runtime.** For every primitive: native-signed verifies in WASM,
WASM-signed verifies in native, both directions, over Sources A/B/E.

### What conformance is claimed, per primitive

The conformance report carries this table verbatim, and the release gate reads
"every vector in this inventory passes" rather than "all CAVP vectors pass":

| Primitive           | Standards evidence | Grade                         |
| ------------------- | ------------------ | ----------------------------- |
| `ml-dsa-44`         | ACVP, FIPS 204     | standards conformance         |
| `ml-dsa-65`         | ACVP, FIPS 204     | standards conformance         |
| `ml-kem-768`        | ACVP, FIPS 203     | standards conformance         |
| `ml-kem-1024`       | ACVP, FIPS 203     | standards conformance         |
| `slh-dsa-sha2-128s` | ACVP, FIPS 205     | standards conformance         |
| `falcon-512`        | NIST Round 3 KAT   | **KAT only — no CAVP exists** |

Running ACVP vectors is not a NIST validation. The report states that we execute the
published ACVP vector sets and that no CMVP/CAVP certificate is claimed or implied.

**This record amends the Definition of Done** item "Every approved conformance/KAT
vector passes" to be the operative one, and reads the earlier "All CAVP vectors pass
in both builds" as satisfied by the table above with Falcon's grade stated.

### Storage and reproducibility

Vectors are **fetched, not committed**. `packages/pq-core/vectors/` holds a
`manifest.json` per source — upstream URL, pinned tag or commit, file list, and the
SHA-256 of each file — plus the fetch script. CI and developers run the script; it
fails if any checksum mismatches. The project golden vectors of Source E are the one
exception and are committed, because they are ours and are small.

The report emitted by §5.5 records, per row: vector source and pinned version, the
vendored upstream commit, algorithm, operation, target (`native-linux`,
`native-windows`, `wasm-chromium`), pass count, fail count, and skip count. A run
with zero cases for a primitive is a failure, not a pass.

## Consequences

**Good.** The release gate becomes passable and honest at the same time. Nobody has
to choose between shipping and telling the truth about Falcon, which is the situation
that produces quietly redefined terms in a thesis.

**Good.** Falcon's weaker evidence is now visible in the artefact that examiners
read, and it reinforces the design decision it should reinforce: Falcon is confined
to the device role, and the manual's risk control — keep Falcon device-scoped until
reviewed — has a measurable justification behind it rather than a general worry.

**Good.** Fetch-by-checksum keeps the repository small while making the vector set
exactly reproducible. A changed upstream file fails the fetch instead of silently
changing what "conformance" means between two runs.

**Costly.** CI depends on fetching from GitHub, so an upstream outage or a deleted
tag breaks the conformance job. Mitigation: the fetch is cached in CI, and the
milestone-gate check that already reviews dependency status also confirms the pinned
tags still resolve.

**Costly.** Seven vector sources with different formats means seven parsers. ACVP
JSON, the `.req`/`.rsp` KAT format, PQClean's fixtures and our own JSON are four
distinct shapes. The runner is a non-trivial piece of software and needs its own
tests — a vector runner that silently passes zero cases is the classic failure, which
is why zero-case runs are hard failures.

**Costly.** The Falcon KAT adapter (attached to detached form, plus the DRBG) is code
we own on the conformance path. It is reviewed as cryptographic code.

**Binding on the ETHFALCON work.** ADR 0011's Solidity tests draw from Sources B and
E only, so the on-chain verifier and the off-chain signer are checked against the
same fixtures rather than against each other.

## Alternatives considered

**Claim CAVP conformance for Falcon on the basis of Round 3 KATs.** Rejected: CAVP
means something specific, FIPS 206 is not final, and a thesis that overstates a
conformance claim invites exactly the scrutiny it least wants. The manual's own
instruction — do not hide the gap by reporting one thing as another — applies here as
squarely as it does to the primitive count.

**Drop Falcon until FIPS 206 is final and use ML-DSA-44 for device signing.**
Rejected: it would remove the ≈666-byte signature that the proposal's Table 2 selects
Falcon for and that the record-size and gas budgets are built on, replacing it with
2,420 bytes per user action. It also deletes RQ3's subject, since the ETHFALCON
dispute-path measurement is a Falcon question.

**Generate our own vectors from a reference implementation and treat those as
authoritative.** Rejected: it proves our implementation agrees with a reference we
also chose, which is the differential oracle of Source D — useful, and already
included, but not conformance. Calling it conformance would be circular.

**Commit all vector files into the repository.** Rejected on size, and because a
committed vector file can be edited in a pull request that also changes the
implementation. A checksummed fetch from a pinned upstream tag cannot be adjusted to
make a failing implementation pass.

**Use `wycheproof`-style third-party test suites instead of ACVP.** Rejected as a
primary source: coverage for the FIPS PQC algorithms is thinner than ACVP's and it is
not the authoritative set. Nothing prevents adding it later as an additional source.
