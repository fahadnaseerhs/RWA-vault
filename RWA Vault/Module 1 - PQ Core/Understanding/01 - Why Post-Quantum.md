---
tags: [rwa-vault, m1, explainer]
---
# Why Post-Quantum Cryptography?

## The threat in plain English

Today's public-key cryptography (RSA, ECDSA, ECDH) relies on mathematical problems that classical computers find impossibly hard — factoring huge numbers, or computing discrete logarithms on elliptic curves. A sufficiently large quantum computer running **Shor's algorithm** solves these problems efficiently, breaking every signature and key exchange the internet relies on.

**Timeline:** NIST, NSA, and BSI all recommend starting migration now. The concern isn't just when large quantum computers arrive — it's **harvest-now, decrypt-later**: an adversary records today's encrypted traffic and decrypts it once they have a quantum machine. For a financial system whose records must be valid for decades, this is a real risk.

## What "post-quantum" means

Post-quantum (PQ) algorithms are built on mathematical problems that remain hard for both classical and quantum computers:

| Problem family | Algorithms in PQ Core | Intuition |
|---------------|----------------------|-----------|
| **Lattice-based** | ML-DSA-44, ML-DSA-65, ML-KEM-768, ML-KEM-1024 | Finding the shortest vector in a high-dimensional lattice is hard even for quantum computers. Think of it like finding the closest grid point to a random point in 1000-dimensional space. |
| **Hash-based** | SLH-DSA-SHA2-128s | Security relies only on the collision/preimage resistance of a hash function (SHA-256). Quantum computers can speed up hash attacks with Grover's algorithm, but only by a square-root factor — doubling the hash output negates this advantage. |
| **Lattice + NTRU** | Falcon-512 | A specialised lattice scheme over NTRU rings. Produces the smallest signatures of any PQ scheme (~666 bytes), which matters for on-chain verification gas costs. |

## Two operations, two families

PQ Core provides exactly two cryptographic operations:

### 1. Digital signatures (sign + verify)

Used when one party needs to prove: *"I approved this, and it hasn't been tampered with."*

**In RWA-Vault:** An oracle signs an asset valuation. A custodian signs a proof-of-reserve. An admin signs a registry entry. The Falcon-512 signature is verified on-chain in a Solidity dispute verifier (ETHFALCON).

- **Falcon-512** — smallest signatures, good for on-chain (gas efficient)
- **ML-DSA-44** — NIST standard (FIPS 204), fast, general-purpose
- **ML-DSA-65** — higher security level (category 3) for sensitive operations
- **SLH-DSA-SHA2-128s** — hash-based, minimal assumptions, used as the root-ceremony algorithm (offline only)

### 2. Key encapsulation (encapsulate + decapsulate)

Used when two parties need to derive the same shared secret without ever sending it in the clear. The sender encapsulates a random secret under the recipient's public key → gets a (ciphertext, shared_secret) pair. The recipient decapsulates the ciphertext with their private key → recovers the same shared_secret. Both sides then use this shared secret for symmetric encryption (AES-256-GCM, etc.).

**In RWA-Vault:** Encrypting off-chain asset documents, establishing secure channels between services, key agreement for envelope encryption.

- **ML-KEM-768** — NIST standard (FIPS 203), category 3
- **ML-KEM-1024** — category 5 for maximum security

## Why not just use a library?

We could use `liboqs` or a WebAssembly wrapper around a PQ library. We chose to vendor PQClean's reference C implementations and compile them ourselves because:

1. **Auditability** — every C source file is pinned to an exact commit. The build system verifies sizes at compile time.
2. **Reproducibility** — the Rust toolchain is pinned (1.81.0), the C sources are in-tree. Anyone can rebuild and get the same binary.
3. **No runtime dependencies** — the compiled crate has zero dynamic library dependencies. It's entirely self-contained.
4. **WASM compatibility** — PQClean's clean C compiles to WASM without modifications. `liboqs` does not.

## NIST standards reference

| Standard | Algorithm(s) | Status |
|----------|-------------|--------|
| **FIPS 203** | ML-KEM (Kyber) | Published Aug 2024 |
| **FIPS 204** | ML-DSA (Dilithium) | Published Aug 2024 |
| **FIPS 205** | SLH-DSA (SPHINCS+) | Published Aug 2024 |
| **FIPS 206** | FN-DSA (Falcon) | Draft, expected 2025 |

PQ Core implements all four families. When FIPS 206 is finalised, the Falcon implementation will be updated to match its exact byte encoding.

---

Prev: [[00 - What is PQ Core]] · Next: [[02 - The Six Primitives]] · Up: [[Module 1 - PQ Core]]
