---
tags: [rwa-vault, module, m2]
phase: 1
sprint: 2-3
status: skeleton
updated: 2026-09-26
---
# Module 2 — PQ-PKI & Envelope 🟠

The trust layer: who holds which PQ key, and how every user action and attestation is wrapped, signed and verified. **Nearly every later module is blocked on M2.**

**Depends on:** [[Module 1 - PQ Core]]. The verification service specifically needs **M1 Stage 3** (the Node addon, S3-01…S3-08), because that's how Node calls `verify`.
**Done when:** rotation and revocation work end-to-end, and the replay suite rejects every attack at its named check.

**What exists today:** `packages/envelope-codec` (the `PqEnvelope` type, 38 lines), `services/pq-verifier` (the list of 7 condition names), and an empty `contracts/src/keys/`.

> ⚠️ **The subtasks below are a draft.** Unlike M1, there's no official M2 task breakdown in `docs/`. I derived these from the build plan; review them as a team before treating them as the plan.

**Progress: 0 / 7 tasks · 0 / 47 subtasks**

---

## T0 — Interface PR (required by the cross-cutting rules)
- [ ] **T0.1** Write the `IPQKeyRegistry` Solidity interface (functions, events, errors), no implementation
- [ ] **T0.2** Write the envelope byte-layout spec as an ADR (fields, order, widths, endianness, version byte)
- [ ] **T0.3** Write the TS verifier-service contract (request/response, named failure codes)
- [ ] **T0.4** Get approval from the consumers (M3, M5, M9 owners) before implementation starts

## T1 — `PQKeyRegistry.sol`: three-tier key hierarchy
- [ ] **T1.1** Key record struct: `keyId`, tier, algorithm, public-key hash, owner, `validFrom`, `validTo`, `successor`
- [ ] **T1.2** Tier ↔ algorithm enforcement: Tier 0 = SLH-DSA-SHA2-128s, Tier 1 = ML-DSA-65, Tier 2 = Falcon-512
- [ ] **T1.3** Tier 0 offline root registration (the key is made by `pqctl`, M1 S3-12, and never touches a server)
- [ ] **T1.4** Tier 1 service-key registration, authorised by Tier 0
- [ ] **T1.5** Tier 2 device-key registration (user devices), authorised by the parent tier
- [ ] **T1.6** Events for register, rotate and revoke (the audit trail M9 anchors)
- [ ] **T1.7** Foundry unit tests plus an invariant that a key's tier never changes and records are never deleted

## T2 — Key lifecycle
- [ ] **T2.1** Registration with an explicit validity window
- [ ] **T2.2** Rotation: the successor must be registered **before** the predecessor retires (overlap window)
- [ ] **T2.3** Non-destructive revocation: set `validTo` and never delete, so historical signatures stay verifiable
- [ ] **T2.4** `resolveKey(keyId, timestamp)`: was this key valid at time *t*?
- [ ] **T2.5** Tests: rotate with no gap, revoke, old signature still verifies at its own time, new signature with a revoked key fails
- [ ] **T2.6** Access control: who can rotate or revoke at each tier

## T3 — Canonical `PQEnvelope` codec (TS + Rust, byte-identical)
- [ ] **T3.1** Finalise the byte layout from the T0.2 ADR
- [ ] **T3.2** TS encoder/decoder in `packages/envelope-codec`
- [ ] **T3.3** Rust encoder/decoder (used by the M9 offline verifier)
- [ ] **T3.4** "Signing bytes" function: the envelope with the signature field zeroed
- [ ] **T3.5** Reject non-canonical encodings (trailing bytes, wrong lengths, unknown version)
- [ ] **T3.6** Shared golden-vector fixtures that must produce identical bytes in TS and Rust
- [ ] **T3.7** Round-trip + fuzz tests on decode (never panic, always a typed error)
- [ ] **T3.8** Envelope hash function (the leaf hash that M9 uses)

## T4 — Seven-condition verifier
Each check is its own function and fails with its **named** code (the list is already in `services/pq-verifier/src/index.ts`).
- [ ] **T4.1** `algorithm-allow-listed-for-action`
- [ ] **T4.2** `signer-resolves-to-active-unrevoked-key` (reads PQKeyRegistry)
- [ ] **T4.3** `domain-separator-matches` (define it as chainId + contract + action)
- [ ] **T4.4** `clock-inside-validity-window` (with a defined clock-skew tolerance)
- [ ] **T4.5** `nonce-equals-stored-plus-one`
- [ ] **T4.6** `signature-verifies-over-zeroed-envelope` (calls M1 `verify` through the Node addon)
- [ ] **T4.7** `payload-hash-matches-executed-payload`
- [ ] **T4.8** Fixed check order (cheap checks first, signature check late); the first failure wins and is reported by name

## T5 — Nonce store + stateless verification service
- [ ] **T5.1** PostgreSQL schema: `(signer_key_id, last_nonce)`
- [ ] **T5.2** Atomic compare-and-increment (row lock or conditional `UPDATE`) so two concurrent requests can't both pass
- [ ] **T5.3** NestJS `pq-verifier` service, stateless and **holding no signing keys** (no authority)
- [ ] **T5.4** `POST /verify` endpoint returning accept, or reject with the named check
- [ ] **T5.5** Key-registry reads from chain (with safe caching, or none)
- [ ] **T5.6** Health checks and structured logs with no key or signature bytes

## T6 — Adversarial replay suite
Each case must assert rejection **at the named check**, not just "rejected".
- [ ] **T6.1** Nonce reuse → `nonce-equals-stored-plus-one`
- [ ] **T6.2** Nonce gap (skipping ahead) → `nonce-equals-stored-plus-one`
- [ ] **T6.3** Concurrent same-nonce race → exactly one accepted
- [ ] **T6.4** Cross-domain replay (other chain, contract or action) → `domain-separator-matches`
- [ ] **T6.5** Expired and not-yet-valid intents → `clock-inside-validity-window`
- [ ] **T6.6** Revoked key and rotated-out key → `signer-resolves-to-active-unrevoked-key`
- [ ] **T6.7** Wrong algorithm for the action (e.g. Falcon on a Tier 1 action) → `algorithm-allow-listed-for-action`
- [ ] **T6.8** Tampered payload → `payload-hash-matches-executed-payload`; tampered signature → `signature-verifies-over-zeroed-envelope`

---

## Suggested order
T0 → T3 (codec; needs no chain) → T1 + T2 (contract) → T4 + T5 (service, once M1 Stage 3 lands) → T6

Prev: [[Module 1 - PQ Core]] · Next: [[M3 - Registry & Compliance]] · Up: [[All Modules]]
