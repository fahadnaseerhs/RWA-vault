# ADR 0006 — The M1 byte encoding contract

- **Status:** Proposed
- **Date:** 2026-08-20
- **Deciders:** Fahad Naseer, Hassan Attique, Fawaz Asif

## Context

M1's governing invariant is that it signs bytes, not business objects, and must never
silently re-serialise, normalise, trim, hash differently, or alter the caller's
message. That invariant is only enforceable if the byte-level contract is written
down first: what an algorithm identifier is, what a key is, what a signature is, how
long each may be, and what — if anything — happens to a message between the caller
and the signing primitive.

Four consumers must agree on this contract byte-for-byte: the Rust core, the
TypeScript wrapper, the WASM build, and the Solidity dispute verifier. A divergence
between any two of them is a signature-verification failure, and
`packages/envelope-codec` already carries that warning in its own package
description. §7 of the manual requires the contract frozen before the public API
stabilises, and requires golden vectors that all four consumers read.

Two things are deliberately _not_ settled here. The `PqEnvelope` field layout is M2's
(`packages/envelope-codec`), and the ETHFALCON calldata shape is pinned in ADR 0011
against a specific verifier commit. This record fixes what M1 owns: the primitive
boundary, and the encoding rules M2 and the verifier must build on.

## Decision

### 1. Algorithm identifiers

The API identifier is a lowercase ASCII string, matching the existing
`PqAlgorithm` union exactly, extended by ADR 0002. Every identifier also has a
one-byte wire code for use anywhere a compact canonical form is needed — including
M2's signed envelope bytes — so that no signed structure ever depends on a string
encoding.

| Wire code | Identifier          | Kind      |
| --------- | ------------------- | --------- |
| `0x00`    | _reserved, invalid_ | —         |
| `0x01`    | `falcon-512`        | signature |
| `0x02`    | `ml-dsa-44`         | signature |
| `0x03`    | `ml-dsa-65`         | signature |
| `0x04`    | `slh-dsa-sha2-128s` | signature |
| `0x05`    | `ml-kem-768`        | KEM       |
| `0x06`    | `ml-kem-1024`       | KEM       |

`0x00` is permanently invalid so that a zeroed buffer never decodes to a valid
algorithm. **Codes are never reused.** Retiring a primitive burns its code forever;
a replacement takes the next free value. This is what makes the allow-list a
downgrade defence rather than a lookup table.

### 2. Key, signature and ciphertext formats

Raw byte strings, exactly as the underlying implementation emits them. No ASN.1, no
DER, no COSE, no JWK, no PEM, no base64, no length prefix, no algorithm tag attached
to the material itself. Encoding for transport or storage happens at an integration
boundary; M1 uses `Uint8Array` at the TypeScript surface and `&[u8]`/`Vec<u8>` in
Rust throughout.

Secret wrappers zeroize the live `Vec` allocation they own, not the allocator's
history. A caller that writes secret material and then triggers `Vec`
reallocation before ownership transfer may leave an unreachable copy in freed
heap memory. Secret-producing paths therefore allocate final capacity before
writing bytes and do not resize afterward.

Every length is exact. There are no ranges and no maxima to compare against, because
`falcon-padded-512` (ADR 0003) makes even Falcon fixed-size:

| Identifier          | Public key | Private key | Signature | Ciphertext | Shared secret |
| ------------------- | ---------: | ----------: | --------: | ---------: | ------------: |
| `falcon-512`        |        897 |        1281 |       666 |          — |             — |
| `ml-dsa-44`         |       1312 |        2560 |      2420 |          — |             — |
| `ml-dsa-65`         |       1952 |        4032 |      3309 |          — |             — |
| `slh-dsa-sha2-128s` |         32 |          64 |      7856 |          — |             — |
| `ml-kem-768`        |       1184 |        2400 |         — |       1088 |            32 |
| `ml-kem-1024`       |       1568 |        3168 |         — |       1568 |            32 |

`metadata(algorithm)` returns these numbers from one Rust table. For PQClean,
`build.rs` parses the pinned implementations' `api.h` files and generates the FFI
buffer constants; compile-time assertions require every generated value to equal
the table. SLH-DSA is checked against its Rust implementation's associated
serialization lengths. A mismatch is therefore a build error before any FFI call
can allocate from a wrong value. Live tests then prove the implementations emit
those lengths. The numbers in this ADR remain the specification.

**Every input is length-checked for exact equality before it reaches the underlying
implementation.** A key, signature or ciphertext of the wrong length is
`MalformedKey` / `MalformedSignature` / `MalformedCiphertext`, never a call into C.
This closes §8.4's uncontrolled-allocation and malformed-input concern by
construction: the vendored C is only ever handed buffers of the length it was
compiled to expect.

The one variable-length input is the message, capped at **1 MiB (1,048,576 bytes)**.
The canonical envelope is a few hundred bytes, so the cap is three orders of
magnitude of headroom and exists solely to bound allocation. Over-length is
`MessageTooLong`.

### 3. Message handling — no prehash, no context string

M1 exposes only the pure signing variants. The bytes the caller passes are the bytes
the primitive signs. M1 does not hash the message first, does not prepend a domain
separator, does not append anything, and does not expose ML-DSA's `HashML-DSA` or
SLH-DSA's pre-hash mode.

Where FIPS 204 and FIPS 205 admit a context string, **M1 fixes `ctx` to empty
(length 0)** and does not expose it as a parameter. Domain separation is already a
property of the envelope — `version`, `algorithm`, `chainId`, `contract`, `action`
and `signer` are fields inside the signed bytes, which is a stronger and more
auditable separation than an out-of-band context string, and it is the separation
M2's seven-condition verifier actually checks. Two mechanisms for one job would mean
a signature could be domain-separated one way and checked the other.

This choice has a verification obligation attached: the ACVP vectors for the
external ML-DSA and SLH-DSA interfaces are generated with a context string, and the
vendored implementations must be confirmed in Stage 1 to implement the external
(`ctx`-taking) interface with empty `ctx` rather than the internal one. If a
vendored implementation turns out to expose only the internal interface, that fact
is recorded in the conformance report and the vector set is selected to match — it
is not papered over.

### 4. Endianness

Cryptographic byte strings are opaque and are copied verbatim; endianness does not
apply to them. Every multi-byte integer that M1 defines or that appears in a
structure M1 helps canonicalise is **big-endian**: `chainId` and `nonce` as
`uint256` big-endian, `validFrom`/`validTo` as `uint64` big-endian, lengths as
`uint32` big-endian, the algorithm code as a single byte. Big-endian because the
anchored leaf is a Keccak-256 hash consumed by Solidity, and the EVM's word and ABI
encoding are big-endian; choosing little-endian would put a byte-swap on the one
path where a mistake is only discoverable on-chain.

### 5. Error classes

A closed set, stable across the native, WASM and TypeScript surfaces, each with a
machine-readable code. None carries key, message, or signature bytes in its payload,
and none reports the length of secret material.

`UnsupportedAlgorithm`, `AlgorithmKeyMismatch`, `MalformedKey`, `MalformedSignature`,
`MalformedCiphertext`, `MessageTooLong`, `RngFailure`, `NotInitialised`,
`InternalError`.

`verify` returns a boolean for a well-formed-but-invalid signature and an error only
for malformed input. A cryptographic non-match is an outcome, not an exception.

### 6. Golden vectors

`packages/pq-core/vectors/project/v1/` holds project-level fixtures — for each
primitive: a seed, the derived keypair, a fixed message, the resulting signature or
ciphertext — as JSON with hex-encoded byte fields. They are generated once, reviewed,
committed, and consumed by the Rust tests, the TypeScript tests, the WASM browser
suite, and the Foundry tests. The directory is versioned (`v1`, `v2`, …) and a
version is immutable once merged, for the same reason an ADR is: a fixture that can
be edited is not evidence.

## Consequences

**Good.** Exact-length equality checks everywhere mean the parsing surface in front
of the cryptographic code is a handful of integer comparisons. There is no
length-prefix parser, no tag-length-value decoder, and no variable-size allocation
to get wrong — the classes of bug that produce CVEs in signature libraries are
absent because the formats that carry them are absent.

**Good.** A fixed 666-byte Falcon signature gives M2 a fixed record budget, gives the
anchoring calldata a fixed size, and makes the RQ1 signature-size figure a constant
rather than a distribution.

**Good.** Raw bytes with no self-describing envelope means M1 cannot be confused
about what it is verifying. The algorithm comes from the caller and is checked
against the key length; it is not read out of the key material, so there is no
algorithm-confusion attack surface inside M1.

**Costly.** No prehash means the full message crosses the bridge for every operation.
At envelope sizes this is irrelevant; if a later module ever needs to sign a large
document, it hashes first and signs the hash as its own canonical message, which is
the correct layering anyway.

**Costly.** Raw byte strings are not self-describing, so a key or signature separated
from its algorithm identifier is uninterpretable. That is M2's problem to solve in
the key registry and the envelope, and it is the right place: the pairing of a key
with its algorithm and its validity window is exactly what a key record is for.

**Costly.** Burning wire codes on retirement means the code space is smaller than it
looks. At one byte and six primitives, this will not bind.

**Binding on other modules.** M2's envelope codec must use the wire codes and the
big-endian integer rules above. ADR 0011's Solidity adapter must consume the
666-byte Falcon signature form. Any change to this record is a breaking protocol
change requiring a superseding ADR and a new golden-vector version.

## Alternatives considered

**Use PQClean's variable-length `falcon-512` and carry a length.** Rejected: it adds
a length field to every record and every calldata layout, makes the size budget a
range, and reintroduces a parser in front of the verifier for no benefit beyond
saving a few dozen bytes on the average signature.

**Use a self-describing container — COSE, or a small TLV of `(algorithm, key)`.**
Rejected for the primitive boundary. It would move algorithm selection from the
caller into the parsed bytes, which is an algorithm-confusion surface, and it would
put a decoder in front of the cryptographic code. The pairing belongs one layer up
in M2's key record, where it is governed by a validity window and a revocation
state. Base64 or JSON at the primitive boundary is rejected for the additional
reason that it would mean private-key material existing as an immutable JavaScript
string, which cannot be zeroed.

**Expose a context-string parameter and let callers set it.** Rejected: two
domain-separation mechanisms where the envelope already provides one, and a
parameter that must then be canonicalised, transported, and checked by M2's verifier
as a seventh-and-a-half condition. Fixing it empty keeps "M1 signs exactly the bytes
you gave it" literally true.

**Offer prehash variants for symmetry with FIPS 204/205.** Rejected: nothing in the
protocol signs anything large enough to need it, and each additional variant is
another vector set to run and another way for a signer and a verifier to disagree
about which mode was used.

**Little-endian integers.** Rejected: the leaf hash is consumed by Solidity, and
big-endian is the EVM's native convention. The byte-swap would sit on the path whose
mistakes surface only on-chain.

**Return an error from `verify` on an invalid signature.** Rejected: it conflates "I
could not check this" with "I checked it and it is forged", and it invites callers
to treat a forgery as a transient failure worth retrying.
