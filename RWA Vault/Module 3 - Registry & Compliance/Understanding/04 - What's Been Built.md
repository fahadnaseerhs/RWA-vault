---
tags: [rwa-vault, m3, understanding]
---
# 04 — What's Been Built

As of commit `0b2dd0e` ("feat(registry): scaffold ERC-3643 interface suite and acceptance spec (M3)"), M3 is **interfaces + one acceptance spec**. No implementation contracts exist yet. This is deliberate — the cross-cutting rule in [[All Modules]] is "open every module with an interface-only PR, approved by its consumers before implementation."

## Files in the repo
```
contracts/
├── remappings.txt                 forge-std/ , @openzeppelin/contracts/
├── lib/forge-std                  (submodule)
├── lib/openzeppelin-contracts     (submodule)
├── src/
│   ├── tokens/interfaces/IERC3643.sol              permissioned ERC-20 (166 lines)
│   ├── registry/interfaces/
│   │   ├── IIdentityRegistry.sol                    the gate (100 lines)
│   │   ├── IIdentityRegistryStorage.sol
│   │   ├── IClaimTopicsRegistry.sol
│   │   └── ITrustedIssuersRegistry.sol
│   ├── identity/interfaces/
│   │   ├── IIdentity.sol                            ONCHAINID
│   │   ├── IClaimIssuer.sol
│   │   ├── IERC734.sol                              keys
│   │   └── IERC735.sol                              claims
│   └── compliance/interfaces/
│       ├── IModularCompliance.sol
│       └── IModule.sol
└── test/registry/ERC3643Acceptance.t.sol           abstract behaviour spec (116 lines)
```
Empty `.gitkeep` placeholders also exist for `registry/`, `tokens/`, `vault/`, `lending/`, `oracle/`, `anchoring/`, `keys/` — the homes for future implementations.

## The acceptance spec is the contract with the future
`ERC3643AcceptanceTest` is `abstract` on purpose: Forge does not run abstract test contracts, so it **compiles in CI today with no implementation present**. It defines a `deploySystem()` hook that the implementation PR overrides to deploy and wire the real system; the six assertions then run unchanged. Those six are the merge bar:

| Test | Guarantee |
| ---- | --------- |
| `test_VerifiedWalletCanReceiveMint` | a verified wallet can receive a mint |
| `test_MintToUnverifiedWalletReverts` | **the core RWA guarantee** — no minting to unverified |
| `test_VerifiedToVerifiedTransferSucceeds` | verified → verified transfer works |
| `test_TransferToUnverifiedWalletReverts` | transfer to unverified reverts |
| `test_FrozenWalletCannotTransfer` | a frozen wallet can't send |
| `test_PausedTokenBlocksTransfer` | paused token blocks all transfers |
| `test_RegistryVerificationMatchesHolders` | registry and token agree on who's verified |

## What is NOT built (the whole implementation)
- No concrete `Token`, `IdentityRegistry`, `*Storage`, `ClaimTopicsRegistry`, `TrustedIssuersRegistry`, `ModularCompliance`, or ONCHAINID.
- **No `AssetRegistry` at all** — not even an interface. See [[03 - AssetRegistry State Machine]].
- No admission-predicate code, no `attestedSupply ≤ reserveAmount` invariant test.
- No provider console.
- No deployment/wiring script in `contracts/script/`.
- No binding to the M2 envelope verifier (M2 is itself skeleton-only).

The full build-out is laid out in [[M3 Task Board and Todo]].

Prev: [[03 - AssetRegistry State Machine]] · Up: [[Module 3 - Registry & Compliance]]
