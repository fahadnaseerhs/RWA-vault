---
tags: [rwa-vault, m1, explainer]
---
# What is PQ Core?

PQ Core is the cryptographic foundation of the entire RWA-Vault system. It is a single Rust crate that provides **post-quantum digital signatures** and **key-encapsulation mechanisms (KEMs)** — the two cryptographic building blocks that every other module in the project eventually depends on.

## The one-sentence pitch

> PQ Core lets any part of RWA-Vault — browser, server, or offline ceremony — generate keys, sign data, verify signatures, and exchange secrets using algorithms that a future quantum computer cannot break.

## Why does it exist?

RWA-Vault tokenises real-world assets (gold, real estate, etc.) on a blockchain. Tokens represent ownership, so the system must guarantee:

1. **Authenticity** — a signed certificate proves *who* approved a valuation, registered a lot, or authorised a transfer.
2. **Integrity** — if a single byte of a signed message changes, verification fails.
3. **Confidentiality** — when two parties need to share a secret (e.g. a symmetric key for encrypted off-chain data), the key exchange itself must be safe.

Today's RSA / ECDSA signatures and ECDH key exchanges satisfy these needs. But quantum computers running Shor's algorithm can break all three in polynomial time. NIST has published post-quantum replacements (FIPS 203, 204, 205, and the upcoming FIPS 206 for Falcon). PQ Core implements those replacements so RWA-Vault is quantum-safe from day one, rather than needing a painful migration later.

## How does it work, at a high level?

```
                  ┌────────────────────────────────┐
                  │       Rust core crate           │
                  │  (native/src/ — one codebase)   │
                  │                                 │
                  │  PQClean C sources (vendored)   │
                  │  + slh-dsa Rust crate           │
                  │  + ml-kem Rust crate            │
                  └──────────┬───────────┬──────────┘
                             │           │
            ┌────────────────┘           └────────────────┐
            ▼                                             ▼
   ┌─────────────────┐                          ┌─────────────────┐
   │  WASM target     │                          │  Native target   │
   │  (wasm-bindgen)  │                          │  (napi-rs addon) │
   │  → runs in the   │                          │  → runs in       │
   │    browser        │                          │    Node.js       │
   └────────┬──────────┘                          └────────┬─────────┘
            │                                              │
            ▼                                              ▼
   ┌─────────────────┐                          ┌─────────────────┐
   │  src/wasm.ts     │                          │  src/native.ts   │
   │  createWasm      │                          │  createNative    │
   │  Adapter()       │                          │  Adapter()       │
   └────────┬──────────┘                          └────────┬─────────┘
            │                                              │
            └──────────────┬───────────────────────────────┘
                           ▼
                  ┌─────────────────┐
                  │  PqCoreApi       │
                  │  (shared TS      │
                  │   interface)     │
                  └─────────────────┘
```

Both the browser (WASM) and server (native Node addon) paths compile **the same Rust code** and expose **the same TypeScript interface** (`PqCoreApi`). This means the rest of the project never cares which runtime it's on — it just calls `keygen()`, `sign()`, `verify()`, `encapsulate()`, or `decapsulate()` and gets the same types back.

## Key design decisions

| Decision | Rationale |
|----------|-----------|
| **Rust, not C/C++** | Memory-safe by default; no `malloc`/`free` bugs. Compiles to both native and WASM from the same source. |
| **Vendored PQClean** | Pinned C sources with exact commit hashes. We control what enters the build and can reproduce it byte-for-byte. |
| **One crate, two targets** | Avoids divergence. A fix in the Rust code is automatically a fix on both platforms. |
| **SLH-DSA signing offline-only** | SLH-DSA sign() takes ~200 ms — too slow for server hot paths. Signing happens in `pqctl` (an offline CLI), verification stays in the server addon. |
| **No `Debug`/`Clone` on secrets** | Private keys and shared secrets are zeroised on drop and cannot be accidentally logged. |

## Where does PQ Core sit in the project?

```
M0 (Foundation) → M1 (PQ Core) → M2 (PQ-PKI & Envelope) → everything else
```

M1 is the very first "real" module. M2 (certificates, envelopes) cannot start until M1 is done. Nearly every module beyond M2 inherits its trust model from M1's signatures. This makes PQ Core **the critical path** of the entire project.

---

Next: [[01 - Why Post-Quantum]] · Up: [[Module 1 - PQ Core]]
