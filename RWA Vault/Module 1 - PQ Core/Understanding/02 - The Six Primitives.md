---
tags: [rwa-vault, m1, explainer]
---
# The Six Primitives

PQ Core implements exactly six post-quantum algorithms. Each has a specific role in RWA-Vault. This page explains what each one does, its key sizes, and where in the system it's used.

## Signature algorithms (4)

### Falcon-512

| Property | Value |
|----------|-------|
| Wire code | `0x01` |
| Public key | 897 bytes |
| Private key | 1,281 bytes |
| Signature | 666 bytes |
| NIST level | 1 (128-bit security) |
| Standard | FIPS 206 (draft) |

**What it is:** A lattice-based signature scheme over NTRU polynomial rings. It uses "fast Fourier sampling" during signing to produce compact signatures.

**Why we use it:** Falcon has the **smallest signatures** of any PQ scheme at its security level. This is critical because one of RWA-Vault's research questions (RQ3) asks whether PQ signatures can be verified on-chain at reasonable gas cost. Smaller signatures = less calldata = less gas. The ETHFALCON Solidity verifier (Stage 6) will verify Falcon-512 signatures in a smart contract.

**Where it's used:** On-chain dispute resolution, oracle attestations (when gas matters).

---

### ML-DSA-44 (formerly Dilithium2)

| Property | Value |
|----------|-------|
| Wire code | `0x02` |
| Public key | 1,312 bytes |
| Private key | 2,560 bytes |
| Signature | 2,420 bytes |
| NIST level | 2 (128-bit security) |
| Standard | FIPS 204 |

**What it is:** A module-lattice digital signature algorithm. "ML" stands for Module Lattice. The "44" refers to the matrix dimensions (4x4) of its underlying lattice structure.

**Why we use it:** ML-DSA-44 is the **NIST standard** general-purpose PQ signature. It's fast (sub-millisecond sign and verify), well-studied, and has a straightforward implementation. It's the "default choice" for off-chain signing where signature size doesn't need to be minimised.

**Where it's used:** General-purpose signing throughout the system — custodian signatures on documents, server-side attestations, API authentication tokens.

---

### ML-DSA-65 (formerly Dilithium3)

| Property | Value |
|----------|-------|
| Wire code | `0x03` |
| Public key | 1,952 bytes |
| Private key | 4,032 bytes |
| Signature | 3,309 bytes |
| NIST level | 3 (192-bit security) |
| Standard | FIPS 204 |

**What it is:** The same algorithm family as ML-DSA-44 but with a larger matrix (6x5), giving higher security.

**Why we use it:** When the data being signed has a long lifetime or is especially sensitive (e.g. root certificates, compliance attestations), the extra security margin is worth the larger keys and signatures. NIST category 3 roughly corresponds to AES-192 security.

**Where it's used:** PKI root and intermediate certificates (Module 2), high-value regulatory attestations.

---

### SLH-DSA-SHA2-128s (formerly SPHINCS+-SHA2-128s)

| Property | Value |
|----------|-------|
| Wire code | `0x04` |
| Public key | 32 bytes |
| Private key | 64 bytes |
| Signature | 7,856 bytes |
| NIST level | 1 (128-bit security) |
| Standard | FIPS 205 |

**What it is:** A hash-based signature scheme. Its security depends **only** on the collision resistance of SHA-256. No lattice assumptions, no number theory — just hashing.

**Why we use it:** SLH-DSA is the "insurance policy." If lattice-based cryptography is ever broken (a new mathematical attack, not quantum), SLH-DSA still stands because hash functions are the most conservative assumption in cryptography. This makes it ideal for the **root key ceremony** — the single most sensitive signing operation in the system.

**Trade-off:** Signing is slow (~200 ms) and signatures are large (7.8 KB). That's why we use it only for offline ceremonies, never in server hot paths. The Node.js addon (`native/napi/`) deliberately **rejects SLH-DSA sign requests** (ADR 0005). Only `pqctl` (the offline CLI tool) can sign with SLH-DSA.

**Where it's used:** Offline root-ceremony signing via `pqctl`. Verification is allowed everywhere (including the server addon).

---

## Key encapsulation mechanisms (2)

KEMs are used to establish a shared secret between two parties. Unlike signatures (which are about authenticity), KEMs are about **confidentiality** — agreeing on a symmetric key that can then encrypt data.

### ML-KEM-768 (formerly Kyber768)

| Property | Value |
|----------|-------|
| Wire code | `0x05` |
| Public key | 1,184 bytes |
| Private key | 2,400 bytes |
| Ciphertext | 1,088 bytes |
| Shared secret | 32 bytes |
| NIST level | 3 |
| Standard | FIPS 203 |

**What it is:** A module-lattice key-encapsulation mechanism. The sender takes the recipient's public key, produces a (ciphertext, shared_secret) pair. Only the recipient (with the private key) can recover the shared_secret from the ciphertext.

**Why we use it:** ML-KEM-768 is the standard-grade KEM. It's fast and well-studied. Used wherever two services or a client and server need to agree on a symmetric encryption key.

**Where it's used:** Envelope encryption (Module 2), secure channel establishment, off-chain document encryption.

---

### ML-KEM-1024 (formerly Kyber1024)

| Property | Value |
|----------|-------|
| Wire code | `0x06` |
| Public key | 1,568 bytes |
| Private key | 3,168 bytes |
| Ciphertext | 1,568 bytes |
| Shared secret | 32 bytes |
| NIST level | 5 |
| Standard | FIPS 203 |

**What it is:** The same algorithm family as ML-KEM-768 but at a higher security level (NIST category 5, roughly AES-256 equivalent).

**Why we use it:** For key exchanges protecting the most sensitive data — e.g. encrypting private keys at rest, or wrapping keys that protect compliance-critical documents.

**Where it's used:** High-security key wrapping, long-term encrypted storage.

---

## Size comparison at a glance

| Algorithm | Public key | Signature/Ciphertext | Total overhead |
|-----------|-----------|---------------------|----------------|
| Falcon-512 | 897 B | 666 B | 1,563 B |
| ML-DSA-44 | 1,312 B | 2,420 B | 3,732 B |
| ML-DSA-65 | 1,952 B | 3,309 B | 5,261 B |
| SLH-DSA | 32 B | 7,856 B | 7,888 B |
| ML-KEM-768 | 1,184 B | 1,088 B | 2,272 B |
| ML-KEM-1024 | 1,568 B | 1,568 B | 3,136 B |

For comparison, an ECDSA-P256 signature is 64 bytes with a 33-byte public key. PQ signatures are 10–100x larger. This is the fundamental trade-off: quantum safety comes at a size cost. Falcon-512 minimises this cost for on-chain use.

---

Prev: [[01 - Why Post-Quantum]] · Next: [[03 - Architecture]] · Up: [[Module 1 - PQ Core]]
