---
type: thread
task: T1
module: M3
status: active
tags: [rwa-vault, thread, m3, t1]
updated: 2026-10-28
---
# 💬 Thread — T1 Identity Layer

> Append-only. New entries go at the **bottom**, using [[Template - Thread Entry]]. Never edit or delete an earlier entry;
> correct it with a new entry that links to it. Current state = the last entry.

**Task:** [[Tasks/T1 - Identity Layer]] · **ADRs:** 0012, 0013, 0015, 0016, 0025

---

### 2026-10-28 11:20 PKT · 👤 Fahad → ⌨️ Coder · DECISION-NEEDED
**Context:** T1.1. Upstream onchain-id pins `pragma solidity 0.8.17` exactly; it cannot compile under the 0.8.26 pin without patching (ADR 0012 revisit trigger).
**On Disk Now:** `contracts/lib/onchain-id` (not yet added)
**Message:** Fahad chose **vendor unmodified, compiled with 0.8.17 for that folder only** (2026-10-28, decision card). No fork, no superseding ADR.
**Action Needed:** ⌨️ Coder vendors tag 2.2.1.
**Unblocks:** T1.1

---

### 2026-10-28 11:25 PKT · ⌨️ Coder → 🐞 Debugger · HANDOFF
**Context:** T1.1–T1.6 together, because T3 needs a working `isVerified`.
**On Disk Now:** `.gitmodules` → `contracts/lib/onchain-id` @ `a483cda` (tag 2.2.1) · `contracts/foundry.toml` → `compilation_restrictions` (`lib/onchain-id/**` and `src/identity/vendor/**` `=0.8.17`; everything else `=0.8.26`; global `solc_version` removed) · `src/identity/vendor/OnchainId.sol` (0.8.17 import wrapper) · `src/access/OwnerAgentRoles.sol` · `src/registry/{ClaimTopicsRegistry,TrustedIssuersRegistry,IdentityRegistryStorage,IdentityRegistry}.sol` · `test/helpers/IdentityFixture.sol` · `test/identity/IdentityLayer.t.sol` · `forge test` → `110 tests passed, 0 failed` (31 new) · artifacts: `Identity`/`ClaimIssuer` built by `0.8.17+commit.8df45f5f`, ours by `0.8.26+commit.8a97fa7a`.
**Message:**
1. Our 0.8.26 code reaches the vendored contracts only through `src/identity/interfaces`; tests deploy them with `deployCode("Identity.sol:Identity")` and issue **real ECDSA claims**, so the ADR 0012 "two codebases must agree" risk is exercised (selectors matched; `getClaim`, `isClaimValid`, `revokeClaimBySignature`, `addKey` all work through our interfaces).
2. `isVerified`: identity set, and for every required topic a claim with id `keccak256(abi.encode(issuer, topic))` from an issuer trusted for that topic that `isClaimValid` still accepts. Calls into identities and issuers are `try`-wrapped, so a hostile identity reads as unverified (test `test_HostileIdentityFailsClosed`).
3. The `KYC` topic number is not fixed anywhere in the vault; tests use `1`. 🧭 Researcher: name the value for T5.1.
4. Upstream quirk, recorded not changed: a MANAGEMENT key (purpose 1) also counts as a CLAIM key in `keyHasPurpose`, so the KYC issuer's manager key can sign valid claims. Operator runbook should keep the manager key on the multisig.
5. Caps follow T-REX: 15 topics, 50 issuers, 15 topics per issuer, 300 registries per storage.
**Action Needed:** 🐞 Debugger reviews (note the foundry.toml change: CI needs both compilers; online mode fetches exactly 0.8.17 and 0.8.26). 🧭 Researcher rules on 3.
**Unblocks:** T3.1 (token needs `isVerified`)

---

Up: [[Tasks/T1 - Identity Layer]]
