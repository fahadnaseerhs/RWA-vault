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

**KYC a devnet wallet (`VerifyWallet`, anvil only):** gives the wallet an ONCHAINID with a KYC claim from the project issuer and registers it. Refuses off anvil with `VerifyWalletDevnetOnly()`.
```bash
export M3_WALLET_PK=<anvil key 3>                # the provider wallet's own key; devnet only
forge script script/VerifyWallet.s.sol --sig "run(address,uint16)" $(cast wallet address $M3_WALLET_PK) 586 --rpc-url local --broadcast
# prints: VERIFIED wallet 0x…  identity 0x…
```

## 7. Onboard an asset lot (T6.1a)
One-time setup, from the repo root: `pnpm install`, `pnpm --filter @rwa-vault/types build`, and `pnpm pq:addon` (builds the pq-core ML-DSA-65 addon with `cargo`; Rust 1.81+).

The four commands of a fresh devnet onboarding (AC-24), with the §6 environment still set:
```bash
# 1. deploy (from contracts/), §6
forge script script/DeployM3.s.sol --rpc-url local --broadcast
# 2. KYC the provider wallet (from contracts/), §6
forge script script/VerifyWallet.s.sol --sig "run(address,uint16)" $(cast wallet address $M3_WALLET_PK) 586 --rpc-url local --broadcast
# 3. a signed custodian attestation (from the repo root; anvil only). --ts takes now, stale, or Unix seconds
node scripts/onboard/make-fixture-attestation.mjs --asset gold-lot-002 --reserve 999900000000000000000 --seq 1 --ts now
# 4. onboard (from the repo root). Without --broadcast it is a dry run that sends nothing
node scripts/onboard/run.mjs contracts/script/input/gold-lot-002.json --broadcast
```
Use `node scripts/onboard/run.mjs` when the exit code matters: `pnpm m3:onboard` runs the same thing but pnpm turns every non-zero exit into `1`.

`contracts/script/input/gold-lot-002.json` is a ready example input: provider = anvil account 3, token = the address a fresh anvil deployment gives, attestation = the file step 3 writes. For your own lot, copy it and change `assetId`, the weights, `providerWallet`, `token` (= `.token` in `contracts/deployments/31337.json`) and the attestation path; `intendedSupply` must equal `grossWeight × fineness / 10000`.

Step 3 writes only under `contracts/.onboard/` (gitignored), so a rehearsal leaves git clean: the devnet custodian keypair (`keys/`, made once and reused), its public key and hash (`custodian.mldsa65.pub`, `custodian.json`) and the envelope `<slug>.seq<n>.att.json`. On anvil, stage 1 checks the signature against that devnet key when it exists; on any other chain it uses only the committed, registered key in `contracts/script/input/`.

**What it does.** Stage 1 (Node) validates the input with the T6.0 validator, checks the custodian's ML-DSA-65 signature against the custodian key (the committed `contracts/script/input/custodian.mldsa65.pub`, or on anvil the devnet key from step 3), whose `keccak256` must match `custodianKeyHash` in the `custodian.json` beside it, and writes `contracts/.onboard/<slug>.verified.json`. Stage 2 is `forge script script/OnboardAsset.s.sol` (no `--ffi`): pre-flight checks, then register → bind (`setTokenFor`, owner) → submit attestation → admit → mint, reading on-chain state first so a re-run continues instead of failing. It ends with a receipt (state, reserve, supply, seq, valuationTs, provider balance, envelope hash, the transaction hashes) and, on a FIXTURE lot, `MS1 FIXTURE ATTESTATION — NOT INDEPENDENTLY VERIFIED`.

**Exit codes** (of `node scripts/onboard/run.mjs`). `0` done (or "already live"), `1` the input file is invalid (every issue is listed as `<json pointer>: <message>`), `2` waiting for the owner multisig to call `setTokenFor` (the `to / data` is printed; re-run after it confirms), `3` the attestation was rejected before anything was sent (`BadAttestationSig`, `AttestationForOtherChain`, `AttestationForOtherAsset`, `CustodianKeyMismatch`, `CustodianKeyMissing`, `MalformedAttestation`), `4` the forge stage stopped on a named error, for example `ProviderNotVerified(0x…)` (run `VerifyWallet` first) or `AdmitRejected(…, "This valuation is 48 hours old; the limit is 24 hours. …")`. Nothing is sent when it exits 1, 3 or 4.

**Check it against the chain:**
```bash
cd contracts
cast call $(jq -r .assetRegistry deployments/31337.json) 'stateOf(bytes32)(uint8)' $(cast keccak gold-lot-002) --rpc-url local   # 2 = LIVE
cast call $(jq -r .assetRegistry deployments/31337.json) 'reserveOf(bytes32)(uint256)' $(cast keccak gold-lot-002) --rpc-url local
cast call $(jq -r .token deployments/31337.json) 'totalSupply()(uint256)' --rpc-url local     # == intendedSupply, ≤ reserve
```

**Tests:** `forge test --match-path test/registry/OnboardAsset.t.sol` (stage 2) and `pnpm test:onboard` (stage 1, needs `pnpm pq:addon`).

### 7b. The same onboarding in the console (T6.1b)
One-time, from the repo root, after §7's setup: `pnpm pq:wasm` (pq-core's WASM verifier; needs `cargo install wasm-pack --version 0.13.1 --locked`, the `wasm32-unknown-unknown` target and clang) and `pnpm --filter @rwa-vault/pq-core build`. After steps 1–3 of §7 (the page bundles `contracts/deployments/<chainid>.json` and the custodian key when it starts):
```bash
pnpm --filter @rwa-vault/ops-console dev        # http://localhost:5173
```
Connect with the **agent** key: a browser wallet, or on anvil only "Anvil dev key" with anvil key 1 (the owner key is refused). Then: **1 Asset** paste `contracts/script/input/gold-lot-002.json` (Next waits until the provider is KYC-verified) → **2 Attestation** load `contracts/.onboard/gold-lot-002.seq1.att.json` (the custodian signature is checked in the browser) → **3 Admit** "Register asset", then give the shown `to / data` to the owner multisig (on anvil: `cast send <to> <data> --rpc-url local --private-key $M3_OWNER_PK`) and press "Re-check", then "Submit attestation and admit" once clauses 1–4 are ticked → **4 Mint** → receipt with `supply ≤ reserve` ✅. The page can only register, submit an attestation, admit and mint.

Where GitHub downloads are blocked, `pnpm pq:wasm` fails while wasm-pack tries to install `wasm-bindgen` itself. Install it yourself, then build without the auto-install (from `packages/pq-core`; the `wasm-opt` step is skipped, and the unoptimised package is fine for MS1):
```bash
cargo install wasm-bindgen-cli --version 0.2.127 --locked
WASM32_UNKNOWN_UNKNOWN_CLANG=clang RUSTFLAGS="-C link-arg=--error-unresolved-symbols" \
  wasm-pack build native --target web --out-dir ../pkg --release --locked --mode no-install
```

Tests: `pnpm --filter @rwa-vault/ops-console test` (component tests; the WASM clause-1 test runs when `pnpm pq:wasm` has been built).

## 8. The "bypass" demo (T6.3)
The chain refuses on its own; no script or console is involved. After §7 (the provider, anvil account 3, holds the lot), from `contracts/`:
```bash
TOKEN=$(jq -r .token deployments/31337.json)
UNVERIFIED=0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc   # anvil account 5, never KYC'd
cast send $TOKEN "transfer(address,uint256)" $UNVERIFIED 1 --rpc-url local --private-key $M3_WALLET_PK
# expect: Error: Failed to estimate gas: ... execution reverted: custom error 0x69d5fea9: ...
#         ReceiverNotVerified(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc)
```
`0x69d5fea9` is `cast sig "ReceiverNotVerified(address)"`; cast prints the decoded name when it can read the project's build output. Nothing is sent, because the revert happens at gas estimation.

The automated version is `forge test --match-path test/registry/BypassTest.t.sol` (AC-17 as corrected by the T3 spec §10): a direct transfer or mint to an unverified wallet → `ReceiverNotVerified`; a mint while the asset is PENDING or FROZEN, while its valuation is stale, or beyond its reserve → `TransferNotCompliant(0x0, to, amount)`; a transfer while the asset is FROZEN still succeeds (ADR 0019 §6).

## Where things live
```
contracts/
├── foundry.toml          toolchain config (solc 0.8.26 + 0.8.17 for onchain-id, optimizer 200)
├── remappings.txt        forge-std/ , @openzeppelin/contracts/ , @onchain-id/solidity/
├── lib/                  submodules
├── src/                  access, identity, registry, compliance, tokens
├── test/                 unit, acceptance, invariant and script tests
├── script/               DeployM3, VerifyWallet, OnboardAsset; input/ = example lot + devnet custodian key
└── deployments/          <chainid>.json written by DeployM3 (31337 is gitignored)
scripts/onboard/          stage 1 of `pnpm m3:onboard` (Node: validate, verify ML-DSA-65, fixture generator)
```

Up: [[Module 3 - Registry & Compliance]] · Related: [[M3 Task Board and Todo]]
