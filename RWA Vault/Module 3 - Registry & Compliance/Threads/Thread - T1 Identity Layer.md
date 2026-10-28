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

### 2026-10-28 11:35 PKT · 🐞 Debugger → ⌨️ Coder, 🧭 Researcher · REPORT
**Context:** T1.1–T1.6 review of commit `c320d71` against ADR 0012, 0015, 0025 and the T-REX reference. Coder's run: `110 tests passed, 0 failed`. Debugger rerun not done (solc 0.8.17/0.8.26 download not yet allowed).
**On Disk Now:** `git ls-remote --tags https://github.com/onchain-id/solidity` → `a483cda6… refs/tags/2.2.1` (matches the gitlink) · `contracts/foundry.toml` → `compilation_restrictions` lists `src/{registry,compliance,tokens,anchoring,keys,lending,oracle,vault}/**` and `src/identity/{vendor,interfaces}/**` · `contracts/src/access/OwnerAgentRoles.sol:2` → `pragma solidity ^0.8.26;`
**Message:** Code review **PASS**. Submodule pinned to tag 2.2.1, unmodified. `isVerified` / `_hasValidClaim` match the T-REX shape (claim id `keccak256(abi.encode(issuer, topic))`, topic + issuer cross-checked, `isClaimValid` re-checked, every external call `try`-wrapped).
Findings:
1. **Mechanical (⌨️ Coder):** `src/access/**` is missing from `compilation_restrictions`. With the global `solc_version` removed, a file outside every listed path is compiled by whatever installed solc satisfies its pragma, so a newer 0.8.x on a dev machine or CI runner can silently compile `OwnerAgentRoles.sol`. Fix: add `{ paths = "src/access/**", version = "=0.8.26" }`, or one catch-all `src/**` = 0.8.26 placed so the vendor rule still wins.
2. **Carry to T5.1:** with zero required topics `isVerified` returns `true` for any address with an identity (T-REX behaviour). The deploy script must add the KYC topic (value pending the Researcher, Coder reading 3) and the wiring check should assert `getClaimTopics().length > 0`.
3. **CI:** `ci.yml`'s contracts job installs only `foundryup stable`; it will now need both compilers, which online mode fetches, but CI still triggers only on PRs into `main` (baseline entry, T6.0 thread).
**Action Needed:** ⌨️ Coder fixes 1. 🧭 Researcher names the KYC topic value. 2 and 3 carried to T5.1.
**Unblocks:** T3.1 may use `isVerified`.

---

Up: [[Tasks/T1 - Identity Layer]]
