---
tags: [rwa-vault, m3, running]
---
# How to Run Module 3

M3 is a **Foundry** project under `contracts/`, deliberately outside the pnpm workspace (Foundry has its own toolchain). All commands below are run from `contracts/` unless noted.

## Prerequisites
- **Foundry** (`forge`, `anvil`, `cast`). Install: `curl -L https://foundry.paradigm.xyz | bash` then `foundryup`.
- Git submodules present: `forge-std` and `openzeppelin-contracts` under `contracts/lib/` (added in commit `0b2dd0e`).
- Solidity `0.8.26` (pinned in `contracts/foundry.toml`).

## 1. Fetch submodules (first time, or after clone)
```bash
git submodule update --init --recursive
```
**What it does:** pulls `contracts/lib/forge-std` and `contracts/lib/openzeppelin-contracts` at their pinned commits. `contracts/remappings.txt` maps `forge-std/` and `@openzeppelin/contracts/` to them.

## 2. Build
```bash
cd contracts && forge build
```
**Expected today:** the interface suite + the `abstract` acceptance spec compile. Because `ERC3643AcceptanceTest` is `abstract`, Forge compiles it but does not run it — so the build is green with **no implementation present**.

## 3. Test
```bash
cd contracts && forge test -vvv
```
**Expected today:** 0 tests executed (the only test contract is abstract). Once the implementation PR adds a concrete subclass of `ERC3643AcceptanceTest` that overrides `deploySystem()`, the six acceptance tests run here unchanged.

Run a single group once implemented:
```bash
forge test --match-contract ERC3643 -vvv
forge test --match-test test_MintToUnverifiedWalletReverts -vvv
```

## 4. Invariant run (once AssetRegistry lands — T4.5)
```bash
forge test --match-test invariant_attestedSupplyLeReserve -vvv
```
Asserts `attestedSupply ≤ reserveAmount` holds under fuzzed mint/burn/attest sequences.

## 5. Gas snapshot (T7.2)
```bash
forge snapshot
```
Writes `.gas-snapshot`; diff it in PRs to catch regressions on `mint`/`transfer`/`admit`.

## 6. Local devnet + deploy (once T5 scripts exist)
```bash
anvil &                                  # local chain on :8545
forge script script/DeployM3.s.sol \
  --rpc-url http://localhost:8545 --broadcast
```
Wires token ↔ registry ↔ storage ↔ topics ↔ issuers ↔ compliance ↔ asset-live module, then onboards one gold lot and mints (the MS1 smoke path).

## 7. The "unaided onboarding" and "bypass" demos (T6)
- **Onboarding:** run the provider script/console (Q9) end-to-end; a non-author should complete it with only this note.
- **Bypass test:** call `token.transfer` directly via `cast send` with an **unverified** recipient and confirm it reverts with `ReceiverNotVerified`:
```bash
cast send $TOKEN "transfer(address,uint256)" $UNVERIFIED 1 --rpc-url http://localhost:8545 --private-key $PK
# expect: execution reverted
```

## Where things live
```
contracts/
├── foundry.toml          toolchain config (solc 0.8.26, optimizer 200)
├── remappings.txt        forge-std/ , @openzeppelin/contracts/
├── lib/                  submodules
├── src/                  implementations go here (today: interfaces only)
├── test/                 ERC3643Acceptance.t.sol (abstract) + future concrete tests
└── script/               deploy scripts (T5 — not yet created)
```

Up: [[Module 3 - Registry & Compliance]] · Related: [[M3 Task Board and Todo]]
