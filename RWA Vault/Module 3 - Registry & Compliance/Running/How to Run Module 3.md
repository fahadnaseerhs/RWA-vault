---
tags: [rwa-vault, m3, running]
---
# How to Run Module 3

M3 is a **Foundry** project under `contracts/`, deliberately outside the pnpm workspace (Foundry has its own toolchain). All commands below are run from `contracts/` unless noted.

## Prerequisites
- **Foundry** (`forge`, `anvil`, `cast`). Install: `curl -L https://foundry.paradigm.xyz | bash` then `foundryup`. Where that host is blocked, `npm i -g @foundry-rs/forge @foundry-rs/anvil @foundry-rs/cast` installs the same binaries.
- **Two compilers** (Q23 = A): `0.8.17` for the vendored `onchain-id` only, `0.8.26` for everything else. `contracts/foundry.toml` pins them per path with `compilation_restrictions`; Foundry downloads both on first build. If `binaries.soliditylang.org` is blocked, put the GitHub release binaries at `~/.svm/0.8.17/solc-0.8.17` and `~/.svm/0.8.26/solc-0.8.26` and build with `FOUNDRY_OFFLINE=true`.

## 1. Fetch submodules (first time, or after clone)
```bash
git submodule update --init --recursive
```
**What it does:** pulls `contracts/lib/forge-std`, `contracts/lib/openzeppelin-contracts` (5.1.0) and `contracts/lib/onchain-id` (tag `2.2.1`, `a483cda`, unmodified). `contracts/remappings.txt` maps `forge-std/`, `@openzeppelin/contracts/` and `@onchain-id/solidity/` to them.

## 2. Build
```bash
cd contracts && forge build
```
**Expected:** `Compiler run successful!`. `out/Identity.sol/Identity.json` and `out/ClaimIssuer.sol/ClaimIssuer.json` are built by `0.8.17`; every file under `src/`, `test/` and `script/` except `src/identity/vendor/` by `0.8.26`.

## 3. Test
```bash
cd contracts && forge test
```
**Expected (2026-10-28):** `Ran 11 test suites: 194 tests passed, 0 failed`. The six `ERC3643AcceptanceTest` guarantees run unchanged against the real suite in `test/tokens/ERC3643AcceptanceImpl.t.sol`.

Run a single group:
```bash
forge test --match-contract ERC3643AcceptanceImpl -vvv
forge test --match-path test/registry/AssetRegistry.t.sol
forge test --match-test test_MintToUnverifiedReverts -vvv
```

## 4. Invariant run (T4.5)
```bash
forge test --match-path test/invariant/AttestedSupplyLeReserve.t.sol
```
Three invariants over random mint / burn / transfer / attest / freeze / unfreeze / warp sequences, with mints driven through the token: no mint ever creates supply beyond reserve, supply stays within reserve unless a downward attestation was accepted (ADR 0019 §3), and no mint succeeds while the asset is not LIVE or its reserve is stale (ADR 0021).

## 5. Gas snapshot (T7.2)
```bash
forge snapshot
```
Writes `.gas-snapshot`; diff it in PRs to catch regressions on `mint`/`transfer`/`admit`.

## 6. Local devnet + deploy (T5.1)
Inputs come from the environment only (T5.1 spec §1). On anvil, the well-known anvil test keys are fine; never use them anywhere else.
```bash
anvil &                                         # local chain on :8545
export M3_OWNER_PK=<anvil key 0>  M3_AGENT_PK=<anvil key 1>  M3_KYC_ISSUER_PK=<anvil key 2>
export M3_OWNER=$(cast wallet address $M3_OWNER_PK) \
       M3_AGENT=$(cast wallet address $M3_AGENT_PK) \
       M3_KYC_ISSUER_KEY=$(cast wallet address $M3_KYC_ISSUER_PK) \
       M3_ASSET_REF=gold-lot-001 M3_TOKEN_NAME="QORA Gold Lot 001" M3_TOKEN_SYMBOL=qXAU-001
# optional: M3_VALUATION_WINDOW (default 86400), M3_IDENTITY_STORAGE (reuse shared storage)
forge script script/DeployM3.s.sol --rpc-url local --broadcast
```
**What it does:** deploys and wires topics (seeded with `KYC_TOPIC`) → KYC `ClaimIssuer` → trusted issuers → identity storage → identity registry → asset registry (τ set) → custodian attestation source → compliance + `AssetLiveModule` → token (binds compliance itself), unpauses the token last, runs `verifyWiring` (reverts `WiringMismatch("<what>")`), and writes `contracts/deployments/<chainid>.json`. It does **not** register an asset or call `setTokenFor`; that happens at onboarding (T6.1a). Off anvil, `M3_OWNER` must be a contract (`OwnerMustBeContract`); without `M3_OWNER_PK` the owner calls are printed as `to / data` for the multisig.

**Smoke (anvil only):** `forge script script/DeployM3.s.sol --sig "smoke()" --rpc-url local --broadcast` deploys, then onboards a FIXTURE lot end to end and prints `SMOKE OK: FIXTURE lot LIVE, supply 999900000000000000000`.

**Check the file against the chain:**
```bash
cast call $(jq -r .token deployments/31337.json) 'compliance()(address)' --rpc-url local    # == .compliance
cast call $(jq -r .assetRegistry deployments/31337.json) 'attestationSource()(address)' --rpc-url local  # == .attestationSource
```

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
