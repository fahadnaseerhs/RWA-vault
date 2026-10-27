---
tags: [rwa-vault, m1, explainer]
---
# What Remains (Stages 4–7)

Module 1 is roughly halfway done (49/102 tasks). Stages 0–3 built the foundation — the algorithms work, the adapters exist, the API is usable. Stages 4–7 are about proving correctness, measuring performance, building the on-chain verifier, and packaging everything for release.

## Stage 4 — Conformance (18 tasks)

**Goal:** Prove that our implementations produce the exact same outputs as the reference implementations, using official NIST test vectors.

**What this means practically:**
- Download CAVP (Cryptographic Algorithm Validation Program) test vectors for ML-DSA, ML-KEM, and SLH-DSA from the NIST ACVP server
- Download Round 3 KAT (Known-Answer Test) files for Falcon-512 (Falcon uses a different test format since FIPS 206 isn't finalised yet)
- Write test harnesses that feed each test vector through our implementation and assert the output matches byte-for-byte
- Run these tests on **both** the native build and the WASM build to ensure they're consistent

**Why it matters:** Without conformance testing, we have "it works on our test inputs" but not "it matches the standard." If our ML-DSA implementation produces a different signature than NIST's reference for the same (key, message) pair, something is wrong — maybe an endianness bug, a padding error, or a wrong constant. Conformance vectors catch these.

**Technical details:**
- ML-DSA and SLH-DSA use the FIPS "external interface" with an empty context string and no prehash
- Falcon uses the Round 3 KAT format (precomputed `(sk, pk, msg, sig)` tuples)
- The `kat` Cargo feature gates KAT-specific code. ADR 0007 says this feature is refused in optimised builds — you can only run KAT tests in debug/test configuration

## Stage 5 — Benchmarks (12 tasks)

**Goal:** Measure how fast each algorithm runs and how large its outputs are, on real hardware.

**What this means practically:**
- Rust benchmarks (via `criterion`) measuring keygen, sign, verify, encapsulate, decapsulate latency for all six algorithms
- TypeScript benchmarks measuring end-to-end latency through the adapters (native and WASM)
- Size measurements: actual encoded key and signature sizes, compared to the metadata table
- Cross-platform: desktop (x86_64) and mid-range Android (ARM64 via browser WASM)

**Why it matters:** The build plan and thesis need concrete numbers:
- "Falcon-512 verify takes X ms on desktop, Y ms on a Snapdragon 778G" → feeds into RQ3 (on-chain viability)
- "ML-KEM-768 encapsulate produces Z bytes of ciphertext" → feeds into envelope sizing (Module 2)
- Latency variance across runs tells us if the implementation is timing-safe or has data-dependent branches

## Stage 6 — ETHFALCON dispute verifier (10 tasks)

**Goal:** Write a Solidity smart contract that can verify a Falcon-512 signature on-chain.

**What this means practically:**
- Implement the NTT (Number Theoretic Transform) arithmetic in Solidity for the Falcon ring `Z[x]/(x^512+1)`
- Implement the Falcon verification algorithm: hash-to-point, polynomial arithmetic, norm check
- Deploy to a local Hardhat devnet and measure gas cost
- Publish a gas report answering RQ3: "Can a PQ signature be verified on Ethereum at reasonable cost?"

**Why it matters:** This is a research deliverable (RQ3). The entire reason Falcon-512 was selected as an algorithm is that it might be viable for on-chain verification. This stage proves (or disproves) that hypothesis with measured gas numbers.

**Why it's later in the pipeline:** Stage 6 needs the conformance vectors from Stage 4 (task S4-14 specifically) to verify that the Solidity verifier agrees with the Rust implementation on standard test inputs.

## Stage 7 — Release gate (9 tasks)

**Goal:** Make Module 1 shippable as a dependency for Module 2.

**What this means practically:**
- CI pipeline: automated Rust tests, TypeScript typechecking, linting, WASM build, addon build
- `scripts/verify-no-kat-symbols.py` — asserts that the production WASM and addon binaries don't contain KAT-test code
- npm package publishing (private registry): `@rwa-vault/pq-core` version 0.1.0
- Documentation: API docs, changelog, migration guide if any interface changed
- S3-05 (prebuilt addon for CI) and S3-10/S3-13 (contract tests) land here as part of CI setup

**Why it matters:** Until Stage 7 is done, Module 2 can't reliably depend on PQ Core in CI. A human can `cargo build` locally, but the CI pipeline doesn't exist yet. This stage is the "green light" for Module 2 to start full implementation.

## Execution order

```
Stage 4 (Conformance)  ─┐
                         ├─► Stage 6 (ETHFALCON — needs S4-14)
Stage 5 (Benchmarks)   ─┘
                              │
                              ▼
                         Stage 7 (Release gate — last)
```

Stages 4 and 5 can run in parallel. Stage 6 needs one output from Stage 4. Stage 7 is always last.

---

Prev: [[04 - What's Been Built]] · Up: [[Module 1 - PQ Core]]
