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
 * | Algorithm        | NIST Standard | Role in RWA-Vault (Table 2)          |
 * |------------------|---------------|--------------------------------------|
 * | Falcon-512       | FIPS 206*     | Device signing (investor PWA)        |
 * | ML-DSA-44        | FIPS 204      | Oracle round signing (service)       |
 * | ML-DSA-65        | FIPS 204      | Service-to-contract operations       |
 * | SLH-DSA-SHA2-128s| FIPS 205      | Root key (offline, key ceremony)     |
 *
 * (*) Falcon is expected in FIPS 206; currently using liboqs's implementation.
 *
 * @see {@link https://csrc.nist.gov/pubs/fips/204/final | FIPS 204 (ML-DSA)}
 * @see {@link https://csrc.nist.gov/pubs/fips/205/final | FIPS 205 (SLH-DSA)}
 */

/**
 * NIST-standardised post-quantum signature algorithms used in the protocol.
 *
 * Each algorithm is assigned to exactly one role (per proposal Table 2) to
 * prevent key reuse across security domains. The `PqAlgorithm` type is a
 * string union rather than an enum so that it serialises cleanly in JSON
 * and can be pattern-matched in switch statements with exhaustiveness checking.
 */
export type PqAlgorithm = "falcon-512" | "ml-dsa-44" | "ml-dsa-65" | "slh-dsa-sha2-128s";

/**
 * Immutable list of all supported PQ algorithms.
 *
 * Used for:
 * - Validating the `algorithm` field in incoming PQEnvelopes (M2)
 * - Populating key-type selection UIs in the ops console (M10)
 * - Generating test matrices that cover all algorithm variants
 *
 * The `as const` assertion ensures TypeScript narrows each element to its
 * literal string type, enabling exhaustive switch/case checking.
 */
export const PQ_ALGORITHMS: readonly PqAlgorithm[] = [
  "falcon-512",
  "ml-dsa-44",
  "ml-dsa-65",
  "slh-dsa-sha2-128s",
] as const;
