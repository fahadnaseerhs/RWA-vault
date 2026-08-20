/**
 * @module @rwa-vault/pq-core
 * @description M1 — Post-quantum cryptographic core.
 *
 * This package is the typed TypeScript wrapper over the Rust/liboqs builds.
 * The Rust crate (in `native/`) compiles to two targets:
 *
 *   1. **WASM** (via `wasm-pack build`): runs in the browser for the investor
 *      PWA (M10). The Falcon-512 device key is generated and stored in
 *      IndexedDB; signing runs in the WASM sandbox. Falcon's Gaussian
 *      sampling is a side-channel hazard, but a browser tab holding one
 *      user's key can carry that risk — a shared service host holding
 *      protocol keys cannot.
 *
 *   2. **Native** (via `cargo build --release`): runs in Node.js services
 *      for ML-DSA and SLH-DSA operations. These algorithms are lattice-based
 *      (ML-DSA) and hash-based (SLH-DSA) with no timing side-channels in
 *      their reference implementations, making them safe for shared hosts.
 *
 * NIST POST-QUANTUM STANDARDS (FIPS 203/204/205):
 *
 * | Algorithm         | NIST Standard | Role in RWA-Vault (Table 2)         |
 * |-------------------|---------------|-------------------------------------|
 * | Falcon-512        | FIPS 206*     | Device signing (investor PWA)       |
 * | ML-DSA-44         | FIPS 204      | Oracle round signing (service)      |
 * | ML-DSA-65         | FIPS 204      | Service-to-contract operations      |
 * | SLH-DSA-SHA2-128s | FIPS 205      | Root key (offline, key ceremony)    |
 * | ML-KEM-768        | FIPS 203      | Service transport (hybrid, B6)      |
 * | ML-KEM-1024       | FIPS 203      | Document confidentiality at rest    |
 *
 * (*) Falcon-512 is NIST Round 3 Falcon, not FN-DSA. FIPS 206 was still a
 * draft as of August 2026, so this is a KAT-conformant implementation and not
 * a CAVP-conformant one — see ADR 0009 for the per-primitive evidence grades,
 * and ADR 0003 for why Round 3 is the required target (the ETHFALCON dispute
 * verifier cannot verify anything else).
 *
 * @see {@link ../../../docs/adr/0002-pq-primitive-inventory.md | ADR 0002 — six primitives}
 * @see {@link ../../../docs/adr/0003-pq-implementation-sources.md | ADR 0003 — implementation sources}
 * @see {@link ../../../docs/adr/0006-byte-encoding-contract.md | ADR 0006 — byte encoding contract}
 * @see {@link https://csrc.nist.gov/pubs/fips/203/final | FIPS 203 (ML-KEM)}
 * @see {@link https://csrc.nist.gov/pubs/fips/204/final | FIPS 204 (ML-DSA)}
 * @see {@link https://csrc.nist.gov/pubs/fips/205/final | FIPS 205 (SLH-DSA)}
 */

/**
 * Immutable list of the four signature algorithms.
 *
 * Used for:
 * - Validating the `algorithm` field in incoming PQEnvelopes (M2)
 * - Populating key-type selection UIs in the ops console (M10)
 * - Generating test matrices that cover all signature variants
 */
export const PQ_SIGNATURE_ALGORITHMS = [
  "falcon-512",
  "ml-dsa-44",
  "ml-dsa-65",
  "slh-dsa-sha2-128s",
] as const;

/**
 * NIST-standardised post-quantum **signature** algorithms used in the protocol.
 *
 * Each algorithm is assigned to exactly one role (per proposal Table 2) to
 * prevent key reuse across security domains. The type is derived from the
 * immutable list so its compile-time and runtime representations cannot drift.
 *
 * Only these four may be passed to `sign`/`verify`. A KEM identifier is a
 * compile-time error there, which is the point of the split.
 */
export type PqSignatureAlgorithm = (typeof PQ_SIGNATURE_ALGORITHMS)[number];

/** Immutable list of the two KEM parameter sets. */
export const PQ_KEM_ALGORITHMS = ["ml-kem-768", "ml-kem-1024"] as const;

/**
 * NIST-standardised post-quantum **key-encapsulation** mechanisms.
 *
 * A KEM is not a signature scheme: these carry `keygen`/`encapsulate`/
 * `decapsulate` and have a ciphertext and a shared secret where a signature
 * scheme has a signature. They are kept in a separate union so that the two
 * API shapes cannot be confused at a call site.
 *
 * ML-KEM-768 is the post-quantum half of the hybrid X25519 + ML-KEM-768
 * transport at boundary B6; ML-KEM-1024 wraps documents at rest. The hybrid
 * *combiner* is deliberately not M1's — see ADR 0002.
 */
export type PqKemAlgorithm = (typeof PQ_KEM_ALGORITHMS)[number];

/**
 * Every post-quantum primitive in the protocol — the six of proposal Table 2.
 *
 * Prefer the narrower {@link PqSignatureAlgorithm} or {@link PqKemAlgorithm}
 * wherever the operation is known. This union is for code that genuinely spans
 * both, such as the conformance matrix, the benchmark harness, and metadata
 * lookup.
 */
export type PqAlgorithm = PqSignatureAlgorithm | PqKemAlgorithm;

/**
 * Immutable list of all six primitives.
 *
 * The count is six, not four: four signature schemes plus two ML-KEM parameter
 * sets. The build plan's "all six primitives" and this package's original four
 * identifiers were never in conflict — the KEMs had simply not been added yet.
 * ADR 0002 works this out from proposal Table 2 and is the authority.
 */
export const PQ_ALGORITHMS: readonly PqAlgorithm[] = [
  ...PQ_SIGNATURE_ALGORITHMS,
  ...PQ_KEM_ALGORITHMS,
] as const;

/**
 * Narrowing predicate: is this identifier a signature scheme?
 *
 * Exists so that code holding a `PqAlgorithm` can reach the signature API
 * without a cast. The runtime check and the type guard come from the same
 * array, so they cannot drift apart.
 */
export function isPqSignatureAlgorithm(algorithm: unknown): algorithm is PqSignatureAlgorithm {
  return (
    typeof algorithm === "string" &&
    (PQ_SIGNATURE_ALGORITHMS as readonly string[]).includes(algorithm)
  );
}

/** Narrowing predicate: is this identifier a KEM? */
export function isPqKemAlgorithm(algorithm: unknown): algorithm is PqKemAlgorithm {
  return (
    typeof algorithm === "string" && (PQ_KEM_ALGORITHMS as readonly string[]).includes(algorithm)
  );
}
