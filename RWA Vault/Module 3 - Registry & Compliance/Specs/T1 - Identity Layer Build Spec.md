---
type: spec
task: T1
module: M3
status: ready to code
researcher: Claude (Researcher role)
depends_on: ["Q01=C", "Q02=A", "Q03=A", "Q23=A"]
tags: [rwa-vault, m3, t1, spec]
updated: 2026-10-28
---
# 🧭 T1 — Identity Layer: build spec (T1.1 → T1.6)

**For the [[Coder Agent]].** Build from this note. The Debugger uses §8 as intended behaviour, and the Researcher
checks §9. Decisions inherited, not to be re-opened: Q1 = C (vendor `onchain-id`, build the registries, ADR 0012),
Q2 = A (one topic, `KYC`), Q3 = A (ECDSA claims from one project issuer, ADR 0013), Q7 (owner = multisig, agent =
Tier 1 key, ADR 0015), Q15 (immutable, ADR 0025), Q8 (shared identity storage, ADR 0016).

**Reading of Q19:** the approved order names "T1.1", but T3's `mint` cannot run without `isVerified`, which is T1.5.
So T1 here means T1.1 to T1.6, in that order.

---

## 1. T1.1 — vendor `onchain-id`

**Upstream facts, checked 2026-10-28** (clone of `https://github.com/onchain-id/solidity`):

| Release | Commit | `pragma` | Note |
| ------- | ------ | -------- | ---- |
| `2.2.1` (latest stable) | `a483cda6821e3883497972d36d0c4c1e1693e483` (2024-02-22) | `pragma solidity 0.8.17;` **exact**, all 18 files | Hardhat project, `solidity: "0.8.17"` |
| `2.2.2-beta3` (latest tag, HEAD of main) | `1f3577c…` (2026-09-17) | `^0.8.27` | Beta. Needs a newer compiler than our 0.8.26 pin |

**So the task note's "reconciled to solc 0.8.26" cannot be done without editing upstream.** No released version
compiles under 0.8.26. ADR 0012 says patching upstream means superseding that ADR instead. Fahad decided
[[Questions/Q23 - How do we compile the vendored onchain-id|Q23]] = A on 2026-10-28. Build it like this:

1. Add the submodule at `contracts/lib/onchain-id`, checked out at tag `2.2.1` (`a483cda`). No edits to any upstream
   file, ever.
2. Compile upstream **with its own compiler (0.8.17)** and ours with 0.8.26. Primary route: Foundry per-path
   compiler restrictions in `foundry.toml` (remove the global `solc_version` and add one restriction pinning
   `lib/onchain-id/**` to `=0.8.17` and one pinning `src/**`, `test/**` and `script/**` to `=0.8.26`). Prove it with
   `forge build` printing both compiler versions. **Fallback**, if the installed Foundry does not honour the
   restriction: a second build step,
   `forge build --root lib/onchain-id --contracts contracts --use 0.8.17 --out ../../out-onchainid`, wired into the
   `contracts:build` script, with `out-onchainid/` gitignored.
3. **Never `import` an upstream file from our code.** A 0.8.26 file cannot import a file pinned to 0.8.17. Our code
   talks to identities only through our own `IIdentity` / `IClaimIssuer` (`contracts/src/identity/interfaces/`),
   which match upstream's ABI (checked: `isClaimValid`, `isClaimRevoked`, `revokeClaimBySignature`,
   `getRecoveredAddress`, all of ERC-734/735). Tests and scripts deploy upstream with
   `vm.deployCode("<artifact>", abi.encode(args))` and cast the address to our interface.

**Upstream behaviour our code relies on** (so the tests below are right):
- `new ClaimIssuer(managementKey)` gives a working issuer. `Identity(managementKey, false)` gives a working identity.
  Both are non-proxy, which suits ADR 0025.
- Claim validity: `dataHash = keccak256(abi.encode(identity, topic, data))`, signed as an Ethereum signed message
  (`"\x19Ethereum Signed Message:\n32"`). Valid when the recovered signer's `keccak256(abi.encode(signer))` has key
  purpose **3 (CLAIM)** on the issuer and the signature is not revoked.
- `Identity.addClaim` must be sent by a key with purpose 3 on the **identity**, or by the identity itself. When the
  issuer is not the identity, it calls `issuer.isClaimValid` and reverts on false.
- Claim id = `keccak256(abi.encode(issuer, topic))`.

## 2. T1.2 — ClaimIssuer adapter tests

`contracts/test/identity/ClaimIssuerAdapter.t.sol`. There is no adapter contract: upstream already satisfies our
interface. The tests prove it:
`test_ValidKycClaimIsValid`, `test_RevokedClaimIsInvalid` (via `revokeClaimBySignature`),
`test_ClaimSignedByNonClaimKeyIsInvalid`, `test_ClaimForOtherIdentityIsInvalid`,
`test_RemovedClaimKeyInvalidatesClaim`. One shared fixture helper `_signKycClaim(issuerPk, identity, data)` lives in
`contracts/test/identity/IdentityFixtures.sol`. T1.6, T3 and T6 reuse it.

## 3. Shared access pattern (T1.3 to T1.5, and later T3)

Every contract we write uses the shape `AssetRegistry` already has: `address public immutable owner`, constructor
rejects a zero owner with `NotOwner(address(0))`, and the agent mapping where needed with `isAgent`, `addAgent` and
`removeAgent` (owner-only, not idempotent). Errors: `NotOwner(address)`, `NotAuthorisedAgent(address)`,
`InvalidAgent(address)`, `AgentUnchanged(address)`, and events `AgentAdded` / `AgentRemoved`. These are **the same
names** as `IAssetRegistry`, so T6's translation table covers them once. A shared
`abstract contract OwnerAgentRoles` in `contracts/src/access/` is welcome for the new contracts. Do not retrofit it
into `AssetRegistry`, because its errors are declared in `IAssetRegistry` and would collide. No OpenZeppelin
`Ownable` / `AccessControl` (T0.6 Fix Spec §6).

## 4. T1.3 — `ClaimTopicsRegistry`

`contracts/src/registry/ClaimTopicsRegistry.sol` implementing `IClaimTopicsRegistry`. Owner-only add/remove.
- `uint256 constant KYC_TOPIC = 1;` exported from `contracts/src/registry/ClaimTopics.sol` (a file-level constant), so
  the deploy script, tests and T6 use one value.
- Errors: `ClaimTopicAlreadyExists(uint256)`, `ClaimTopicNotFound(uint256)`, `TooManyClaimTopics()` (cap **15**, the
  T-REX limit, because `isVerified` loops over topics).
- The constructor takes `owner` only. The deploy script seeds `KYC_TOPIC` (T5.1), so it is never hard-wired.

## 5. T1.4 — `TrustedIssuersRegistry`

`contracts/src/registry/TrustedIssuersRegistry.sol` implementing `ITrustedIssuersRegistry`. Owner-only writes.
- Errors: `InvalidIssuer(address)` (zero), `IssuerAlreadyTrusted(address)`, `IssuerNotTrusted(address)`,
  `EmptyClaimTopics()`, `TooManyClaimTopics()` (15 per issuer), `TooManyIssuers()` (50, the T-REX limit).
- Keep a topic → issuers index so `getTrustedIssuersForClaimTopic` is a read, not a scan. Update it on add, remove and
  `updateIssuerClaimTopics`.
- MS1 configuration (T5.1): exactly one issuer, the project KYC `ClaimIssuer`, for `[KYC_TOPIC]`.

## 6. T1.5 — `IdentityRegistryStorage` + `IdentityRegistry`

**Storage** (`contracts/src/registry/IdentityRegistryStorage.sol`): writes only from a **bound** identity registry
(`NotBoundRegistry(address)`). The owner binds and unbinds (`RegistryAlreadyBound`, `RegistryNotBound`,
`TooManyBoundRegistries()` at 300). Errors for data: `InvalidWallet(address)` (zero), `InvalidIdentity(address)`
(zero), `IdentityAlreadyStored(address)`, `IdentityNotStored(address)`. **Shared across assets** (ADR 0016), so it is
deployed once.

**Registry** (`contracts/src/registry/IdentityRegistry.sol`): constructor `(owner, trustedIssuers, claimTopics,
storage)`, all non-zero. Agent writes `registerIdentity`, `batchRegisterIdentity`, `updateIdentity`, `updateCountry`
and `deleteIdentity`. Owner-only setters `setIdentityRegistryStorage`, `setClaimTopicsRegistry` and
`setTrustedIssuersRegistry`, because ADR 0015 puts trust-basis setters behind the multisig.

**`isVerified(wallet)`, the exact algorithm (T-REX semantics):**
1. `identity = storage.storedIdentity(wallet)`. If it is zero, return `false`.
2. `topics = claimTopics.getClaimTopics()`. If the list is empty, return `true` (T-REX behaviour. Our deploy always
   seeds KYC, and a test pins this case).
3. For each topic, find **any** issuer in `trustedIssuers.getTrustedIssuersForClaimTopic(topic)` such that the claim
   `keccak256(abi.encode(issuer, topic))` exists on the identity with that issuer and topic, **and**
   `issuer.isClaimValid(identity, topic, sig, data)` returns true. If no issuer qualifies for a topic, return `false`.
4. **Every external call in steps 1 to 3 is wrapped in `try/catch`, and a revert counts as "not valid".** A broken or
   hostile issuer or identity contract must make one wallet unverified, never make `isVerified` revert. A revert
   there would brick every transfer of the token.

Country is the ISO 3166-1 numeric code as `uint16` (Pakistan = 586). It is stored, but no rule reads it (Q2 = A, no
country module).

## 7. T1.6 — the unit test matrix

`contracts/test/registry/IdentityRegistry.t.sol`, using `IdentityFixtures`:

| Test | Expect |
| ---- | ------ |
| `test_VerifiedWithValidKycClaim` | `true` |
| `test_UnregisteredWalletUnverified` | `false` |
| `test_RegisteredWithoutClaimUnverified` | `false` |
| `test_ClaimFromUntrustedIssuerUnverified` | `false` |
| `test_RevokedClaimUnverified` | `false` |
| `test_IssuerRemovedFromRegistryUnverified` | `false` |
| `test_IssuerTopicsUpdatedWithoutKycUnverified` | `false` |
| `test_IssuerClaimKeyRemovedUnverified` | `false` |
| `test_RevertingIssuerMakesWalletUnverifiedNotRevert` | `false`, no revert (mock issuer that reverts) |
| `test_CountryUpdateDoesNotChangeVerification` | emits `CountryUpdated`, still `true` |
| `test_DeleteIdentityUnverifies` | `false` |
| `test_SharedStorageAcrossTwoRegistries` | identity registered via registry A reads verified via registry B (ADR 0016) |
| `test_EmptyTopicListVerifiesRegisteredWallet` | `true` (pins T-REX semantics) |
| plus gating tests | every owner and agent function rejects the wrong caller with the exact named error |

Every revert assertion uses the exact selector (`vm.expectRevert(abi.encodeWithSelector(...))`). A bare
`vm.expectRevert()` fails review.

## 8. For the Debugger: intended behaviour on the likely ambiguities

| Case | Intended |
| ---- | -------- |
| Same wallet registered twice | `IdentityAlreadyStored(wallet)` |
| `updateIdentity` to the zero identity | `InvalidIdentity(address(0))` |
| Claim present but issuer since removed from the TIR | unverified (step 3 only looks at currently trusted issuers) |
| Issuer trusted for KYC but holds a claim key under another purpose | unverified (purpose 3 only, upstream rule) |
| Anything not in this table | ASK the Researcher. Do not pick a behaviour |

## 9. Acceptance criteria (the Researcher checks these)

- **AC-T1-1** `contracts/lib/onchain-id` is a submodule at `a483cda` with zero local modifications
  (`git -C contracts/lib/onchain-id status --porcelain` is empty).
- **AC-T1-2** `forge build` is green, and upstream is compiled with 0.8.17 while every file under `src/`, `test/` and
  `script/` is compiled with 0.8.26 (shown by build output or artefact metadata).
- **AC-T1-3** No file under `src/`, `test/` or `script/` imports from `lib/onchain-id`
  (`grep -rn "onchain-id" contracts/src contracts/test contracts/script` matches only `deployCode` artefact strings).
- **AC-T1-4** §2 and §7 test lists pass, with exact-selector reverts.
- **AC-T1-5** `isVerified` never reverts (`test_RevertingIssuerMakesWalletUnverifiedNotRevert`).
- **AC-T1-6** `forge fmt --check` is clean. No `Ownable` / `AccessControl` import in the new files.

**Next after T1:** T4 follow-ups and T4.3 ([[Threads/Rounds/T4 - Researcher Rulings (round 1)]]), then T2
([[Specs/T2 - Modular Compliance Build Spec]]).

Up: [[Tasks/T1 - Identity Layer]] · Related: [[Specs/T0.6 - IAssetRegistry Interface]], ADR 0012, 0013, 0015, 0016, 0025
