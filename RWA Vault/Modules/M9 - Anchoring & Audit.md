---
tags: [rwa-vault, module, m9]
phase: 2
sprint: 4-5
status: not-started
---
# M9 — Anchoring & Audit ⬜

**Depends on:** [[Module 2 - PQ-PKI & Envelope]] (envelope hashes are the Merkle leaves)
**Done when:** an exported proof bundle verifies on a machine that has never contacted the platform, epoch numbers strictly increase, and no root is ever overwritten.

## Tasks
- [ ] `PQAnchor.sol`: immutable and non-upgradeable; writes `{root, leafCount, epoch}` once per 60 s epoch
- [ ] Redis Streams batcher: leaves in arrival order, one sorted-pair Keccak-256 tree per epoch (OpenZeppelin MerkleProof construction)
- [ ] Proof service that serves `{leaf, proof, epoch}`
- [ ] Independent Rust CLI verifier that works fully offline
- [ ] Epoch-gap handling: after a stall, the next anchor carries the accumulated leaves and the gap is visible in the epoch numbers

## MS2 demo (week 11)
ONCHAINID claim → mock PKR 5,000 deposit → Falcon-512 deposit intent signed in the browser (WASM) → shares minted (rounded against the depositor) → envelope hash anchored within 60 s → Merkle proof verified offline.

Prev: [[M8 - Settlement Rail]] · Next: [[M6 - Risk Engine]] · Up: [[All Modules]]
