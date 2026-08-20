# ADR 0003 — PQ implementation sources: vendored PQClean C, plus one pure-Rust exception

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

The build plan specifies "Rust bindings over liboqs 0.12 / PQClean", and the M1
manual §8.3 says to pin liboqs at the build-plan version (0.12) and pin the actual
Rust binding crate/commit. That instruction was written before anyone checked
whether the pin is satisfiable. It is not, for three independent reasons found while
freezing Stage 0.

**1. liboqs 0.12.0 does not contain SLH-DSA.** liboqs 0.12.0 (released 9 December 2024) ships `SPHINCS+-SHA2-128s-simple`, sourced from PQClean at the NIST Round 3
submission v3.1 specification (10 June 2022). FIPS 205 is _based on_ SPHINCS+ v3.1
but changes the signing and verification interface to add domain separation between
signing a message directly and signing a digest. Round-3 SPHINCS+ signatures are
therefore not SLH-DSA signatures, and FIPS 205 ACVP vectors do not pass against
them. liboqs gained SLH-DSA in 0.15.0. Shipping `SPHINCS+-SHA2-128s-simple` under
the identifier `slh-dsa-sha2-128s` would make the algorithm identifier false and
would make "all CAVP vectors pass" unachievable for the root-of-trust role.

**2. The Rust binding for liboqs cannot reach a version that has SLH-DSA.** The
`oqs` crate's newest release is 0.11.0 (1 May 2025), which tracks liboqs 0.13.0;
0.10.1 tracks 0.12.0. There is no `oqs` release tracking 0.15.0, so choosing liboqs
does not merely mean bumping a pin — it means writing and maintaining our own
bindgen layer over a CMake project.

**3. liboqs has no browser-WASM path.** liboqs is a CMake C project. The `oqs`
crate documents no `wasm32` target. `build:wasm` in `packages/pq-core/package.json`
invokes `wasm-pack`, which builds `wasm32-unknown-unknown`. There is no supported
route from liboqs to that target, and the browser signer is not optional — it is the
mechanism by which the Falcon device key never leaves the device.

Meanwhile the second half of the build plan's phrase, PQClean, is in better shape
than expected and worse shape than expected at the same time. Better: `crypto_sign`
contains `falcon-512`, `falcon-padded-512`, `ml-dsa-44`, `ml-dsa-65`, and the
`sphincs-*` family; `crypto_kem` contains `ml-kem-512/768/1024`. That covers five of
the six primitives in ADR 0002, with ML-DSA and ML-KEM at the final FIPS 204/203
standards. Worse: **PQClean was archived by its owners on 4 August 2026 and is now
read-only**, and it never shipped SLH-DSA. Its README directs users to the PQ Code
Package organisation (`mlkem-native`, `mldsa-native`, `slhdsa-c`) for maintained
implementations of the standardised algorithms.

One further constraint binds the Falcon choice. The dispute path (ADR 0011) verifies
Falcon signatures on-chain against the ETHFALCON Solidity verifier, which implements
NIST Round 3 Falcon. FIPS 206 (FN-DSA) is still a draft as of August 2026, with
final publication expected late 2026 or later. Whatever produces our Falcon
signatures must produce Round 3 Falcon, or the dispute path cannot verify them.

## Decision

**We vendor PQClean's portable C into the crate at a pinned commit and compile it
ourselves, and we take SLH-DSA from pure Rust because PQClean does not have it.**

| Primitive           | Source                                        | Spec                |
| ------------------- | --------------------------------------------- | ------------------- |
| `falcon-512`        | PQClean `crypto_sign/falcon-padded-512/clean` | NIST Round 3 Falcon |
| `ml-dsa-44`         | PQClean `crypto_sign/ml-dsa-44/clean`         | FIPS 204            |
| `ml-dsa-65`         | PQClean `crypto_sign/ml-dsa-65/clean`         | FIPS 204            |
| `ml-kem-768`        | PQClean `crypto_kem/ml-kem-768/clean`         | FIPS 203            |
| `ml-kem-1024`       | PQClean `crypto_kem/ml-kem-1024/clean`        | FIPS 203            |
| `slh-dsa-sha2-128s` | RustCrypto `slh-dsa` 0.1.0 (pure Rust)        | FIPS 205            |

Five rules govern this:

**Vendored, not depended upon.** The five PQClean schemes are copied into
`packages/pq-core/native/vendor/pqclean/` together with `common/`, the per-scheme
`LICENSE` files, and a `PROVENANCE.md` recording the upstream URL, the commit SHA
the copy was taken from, and the SHA-256 of every file. A `build.rs` compiles them
with the `cc` crate. We do not consume the `pqcrypto-*` crates as a dependency.
Vendoring is the correct posture precisely _because_ upstream is archived: the code
is frozen by definition, so a vendored copy can never drift from a moving upstream,
and the manual's own instruction for third-party cryptographic code — vendor or pin
at an immutable version/commit and record its license and upstream source — is
satisfied literally. It also gives us the build control that ADR 0004 needs.

**`clean` implementations only.** No `avx2`, no `aarch64`. One code path executes on
the reference desktop and inside the browser, which is what makes cross-runtime
byte-identity a property of the build rather than a hope. Benchmark reports must
state that the numbers are portable-C numbers and are therefore a lower bound on
achievable performance (ADR 0010).

**Exactly six schemes are vendored.** Nothing else from PQClean is copied in. This
satisfies the manual's requirement to record enabled algorithms explicitly so unused
algorithms do not silently expand the support surface — structurally: an algorithm
that is not in the tree cannot be reached.

**`falcon-padded-512`, not `falcon-512`.** PQClean's `falcon-512` emits a
variable-length signature; `falcon-padded-512` emits the fixed 666-byte form of the
same signature that the Falcon specification defines. Fixed length matches the
proposal's ≈666 B figure, gives M2 a fixed record budget, gives the dispute path
fixed calldata, and lets every length check in M1 be an equality rather than a range
(ADR 0006). The _identifier_ remains `falcon-512`, because the scheme is Falcon-512;
padding is an encoding of its signature, not a different algorithm.

**`pqcrypto-*` as a test-only differential oracle.** `pqcrypto-falcon` 0.4.1,
`pqcrypto-mldsa` 0.1.2 and `pqcrypto-mlkem` 0.1.1 are added as `dev-dependencies`
only. Conformance tests assert that our vendored build and the independently
packaged build of the same upstream agree byte-for-byte on keygen from seed, sign,
and verify. This is nearly free — same upstream, different build system — and it
catches exactly the failure mode vendoring introduces: a `build.rs` that compiles
the C with wrong flags and produces subtly wrong output that still self-verifies.

For SLH-DSA we take `slh-dsa` 0.1.0 (RustCrypto, Apache-2.0 OR MIT), which
implements FIPS 205 final and exposes `Sha2_128s`. Its documented limitations are a
missing independent audit and stack-allocated signatures and intermediates. Both are
acceptable _for this role specifically_: the root key is offline, used a handful of
times a year, never runs in the browser (so the constrained WASM stack does not
apply), and a 7,856-byte signature on an 8 MB native stack is not a concern. The
conformance evidence is FIPS 205 ACVP vectors (ADR 0009), which is stronger evidence
than we can obtain for Falcon.

**Named migration targets and their triggers**, recorded now so a future upgrade is
a decision rather than a scramble:

- PQClean → PQ Code Package (`mlkem-native`, `mldsa-native`). Trigger: a published
  vulnerability in a vendored scheme, or a project decision to seek
  formal-verification evidence for the lattice code.
- `slh-dsa` → `slhdsa-c` (PQ Code Package). Trigger: an audit requirement for the
  root role, or a decision to unify all six primitives on one C source.
- Falcon Round 3 → FN-DSA. Trigger: FIPS 206 final **and** an ETHFALCON verifier
  that accepts FN-DSA. Both are required; migrating the signer alone breaks the
  dispute path. This is a protocol-breaking change and gets its own ADR when it
  arrives.

## Consequences

**Good.** Every primitive in ADR 0002's inventory has an implementation whose
specification version is known and stated, and five of six come from one upstream at
one commit. The one exception is documented as an exception rather than hidden.

**Good.** The `slh-dsa-sha2-128s` identifier now means FIPS 205, so the
root-of-trust role can be conformance-tested against ACVP vectors. Had we followed
the liboqs 0.12 pin, the highest-authority key in the protocol — the one whose whole
purpose is that the authority to revoke and rebind every lattice key must not itself
rest on lattice hardness — would have been running a superseded specification under
a standard's name.

**Good.** Vendoring plus `clean`-only plus exactly-six removes CMake, removes
liboqs' ~40-algorithm surface, and removes the Windows CMake toolchain requirement
from §8.3. The native build needs a C compiler and nothing else.

**Costly.** We own a `build.rs` and a vendored C tree. That is real maintenance, and
it means a PQClean bug is ours to patch rather than ours to upgrade past. The
differential oracle and the pinned checksums are the controls; the migration
triggers above are the exit.

**Costly.** We deviate from the build plan's stated liboqs 0.12 pin. This record
supersedes that instruction for M1. The thesis must present the deviation with its
reasons — which is a better outcome than presenting a pin that was never
satisfiable.

**Costly.** Two provenance stories instead of one: five schemes from archived C, one
from unaudited pure Rust. Both carry "not independently audited"; neither is
hand-rolled. The proposal's position — rely on reviewed open-source implementations,
never write lattice code ourselves — holds for both.

**Consequential for reporting.** Falcon-512 has no CAVP or ACVP vector set, because
FIPS 206 is not final. Its conformance evidence is Round 3 KATs. The conformance
report must label Falcon's evidence "KAT (NIST Round 3 submission)" and not "CAVP",
and the Definition of Done phrase "All CAVP vectors pass" is read as "every vector
in the approved inventory of ADR 0009 passes" (see ADR 0009).

## Alternatives considered

**liboqs 0.12 via the `oqs` crate, as the build plan says.** Rejected on three
independent grounds, any one of which is sufficient: it has no SLH-DSA, its Rust
binding cannot reach a version that does, and it has no `wasm32` path for the
browser signer that the architecture depends on.

**liboqs 0.15+ with our own bindgen layer.** Rejected: it solves the SLH-DSA gap and
nothing else. The WASM problem is unchanged and is the harder one, CMake enters the
Windows CI, and we would be maintaining a bindgen layer over a 40-algorithm library
to use six of them.

**Depend on the `pqcrypto-*` crates rather than vendoring.** Tempting, and it is the
cheapest route to a working native build. Rejected as the primary path because their
documented WebAssembly support is `wasm32-wasi` with a WASI SDK sysroot, not the
`wasm32-unknown-unknown` that `wasm-pack` builds (ADR 0004), so the browser target
would be fighting a build system we do not control. Vendoring costs one `build.rs`
and buys the build control the WASM target needs. Retained as the test-only
differential oracle, where it is worth more than it would be as a dependency.

**`fn-dsa` (Pornin) for Falcon — pure Rust, `no_std`, and it would make the WASM
build trivial.** Rejected on a hard incompatibility. Its README states that no
FN-DSA draft has been published, that what it implements is not the real FN-DSA,
that it was last adjusted on 22 July 2026 to match a best guess at the forthcoming
draft, and that backward compatibility will **not** be maintained before 1.0. It
does not produce Round 3 Falcon signatures, so the ETHFALCON dispute path could not
verify them, and its own author warns that keys and signatures may stop being
accepted by later versions of the same crate. For a record that must stay checkable
for thirty years, that is disqualifying.

**Pure Rust for everything (`ml-dsa`, `ml-kem`, `slh-dsa` from RustCrypto).**
Rejected. It would make ADR 0004 trivial, which is genuinely attractive, but Falcon
Round 3 has no mature pure-Rust implementation, so the C dependency survives anyway
— and it survives in precisely the algorithm that must run in the browser. Having
paid the C-in-WASM cost for Falcon regardless, paying it for ML-DSA and ML-KEM too
is nearly free, and it keeps those two on the reference-derived C that the
proposal's reviewed-implementations position rests on.

**`fips205` (integritychain) instead of RustCrypto `slh-dsa`.** A close call. It is
`no_std` with no heap allocation and ships WASM examples, which would answer the
stack-space concern directly. Rejected because its newest release is 0.4.1 from
23 December 2024 — roughly twenty months stale — against an actively released
RustCrypto crate, and its advantage is in constraints (heap-free, WASM) that do not
apply to an offline native-only root key.

**Keep round-3 `SPHINCS+-SHA2-128s-simple` and rename the identifier honestly.**
Rejected: the proposal assigns the root of trust category-3 parameters under a NIST
standard, and Table 2's argument is about standing on a _different_ hardness
assumption from the lattice keys it can revoke. Shipping a superseded draft for the
protocol's highest-authority key, in a project whose thesis is about durable
post-quantum authenticity, is the wrong trade even when honestly labelled.
