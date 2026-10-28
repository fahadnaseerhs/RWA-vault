---
type: spec
task: T3
module: M3
status: ready to code
researcher: Claude (Researcher role)
depends_on: ["Q08=A", "Q10=implement", "Q16=A", "T1.5", "T2 + T2 rulings round 1", "T4 rulings round 1"]
tags: [rwa-vault, m3, t3, spec]
updated: 2026-10-28
---
# 🧭 T3 — ERC-3643 Token: build spec (T3.1 → T3.6, plus T4.5)

**For the [[Coder Agent]].** Inherited, not to be re-opened: Q8 = A (one token per asset, no factory, ADR 0016),
Q10 = implement (`forcedTransfer`, `burn`, `recoveryAddress`, ADR 0015), Q16 = A (asset FROZEN blocks mints only,
ADR 0019 §6), ADR 0014 (the token never references an asset or the registry), ADR 0020 (18 decimals, 1 token = 1 fine
gram), ADR 0025 (immutable). T3.5 `TokenFactory` stays deferred.

## 1. Shape

`contracts/src/tokens/Token.sol`, `contract Token is ERC20, IERC3643` on OpenZeppelin **5.1.0** (the pinned
submodule). All checks go in one override of `_update(from, to, value)` plus the entry points below, so no path can
skip them. `name()` and `symbol()` are overridden to read our own storage, because `setName` / `setSymbol` must work
(OZ's are fixed at construction). `decimals()` returns `18`. `version()` returns `"rwa-vault-3643-1.0.0"`.

**Constructor:** `(address owner_, address identityRegistry_, address compliance_, string name_, string symbol_,
address onchainID_)`. Zero owner, registry or compliance reverts `ZeroAddress()`. `onchainID_` may be zero for MS1
(the asset's own ONCHAINID is Phase 3 with the factory). The constructor calls `compliance.bindToken(address(this))`
(T2 rulings). **The token is deployed paused** (T-REX behaviour). T5.1 unpauses it as the last wiring step, so no
transfer can happen against a half-wired suite.

**Roles** (same shape and error names as the T1 spec §3): `owner` is immutable (2-of-3 multisig). Agents come from a
mapping managed by `addAgent` / `removeAgent`.

| Owner (multisig) | Agent (Tier 1) | Holder |
| ---------------- | -------------- | ------ |
| `setName`, `setSymbol`, `setOnchainID`, `setIdentityRegistry`, `setCompliance` (ADR 0015), `addAgent`, `removeAgent`, `scheduleForcedTransfer`, `cancelForcedTransfer`, `forcedTransfer`, `batchForcedTransfer`, `recoveryAddress` | `mint`, `batchMint`, `burn`, `batchBurn`, `pause`, `unpause`, `setAddressFrozen`, `freezePartialTokens`, `unfreezePartialTokens` and their batch forms | `transfer`, `transferFrom`, `approve`, `batchTransfer` |

## 2. Named errors (the T6 §3.4 table grows by these)

```solidity
error NotOwner(address caller);                 error NotAuthorisedAgent(address caller);
error InvalidAgent(address account);            error AgentUnchanged(address account);
error ZeroAddress();
error TokenPaused();                            error TokenAlreadyPaused();     error TokenNotPaused();
error WalletFrozen(address wallet);
error InsufficientUnfrozenBalance(address wallet, uint256 available, uint256 requested);
error ReceiverNotVerified(address wallet);
error TransferNotCompliant(address from, address to, uint256 amount);
error FreezeExceedsBalance(address wallet, uint256 balance, uint256 frozenAfter);
error UnfreezeExceedsFrozen(address wallet, uint256 frozen, uint256 requested);
error ArrayLengthMismatch();                    error BatchTooLarge(uint256 length);   // cap 100
error ForcedTransferNotScheduled(bytes32 id);   error ForcedTransferTimelocked(bytes32 id, uint64 eta);
error ForcedTransferAlreadyScheduled(bytes32 id);
error RecoveryIdentityMismatch(address lostWallet, address investorOnchainID);
error RecoveryKeyNotOnIdentity(address newWallet);
error NothingToRecover(address lostWallet);
```

OZ's own `ERC20InsufficientBalance` / `ERC20InsufficientAllowance` stay as they are. They are standard and decodable.

## 3. The rules, in check order (T3.1, T3.2)

**`transfer` / `transferFrom` / `batchTransfer`:** `!paused` (`TokenPaused`) → `!frozen[from]` and `!frozen[to]`
(`WalletFrozen`) → `value ≤ balanceOf(from) − frozenTokens[from]` (`InsufficientUnfrozenBalance`) →
`identityRegistry.isVerified(to)` (`ReceiverNotVerified(to)`) → `compliance.canTransfer(from, to, value)`
(`TransferNotCompliant`) → move → `compliance.transferred(from, to, value)`. **The sender's verification is not
re-checked** (T-REX semantics: a holder whose KYC lapsed can still exit to a verified wallet, consistent with
ADR 0019 §6 and ADR 0021's "exits stay open").

**`mint(to, amount)` (agent):** `isVerified(to)` (`ReceiverNotVerified`) →
`compliance.canTransfer(address(0), to, amount)` (`TransferNotCompliant(address(0), to, amount)`) → `_mint` →
`compliance.created(to, amount)`. **`canTransfer` runs before `_mint`**, which `AssetLiveModule` relies on (it reads
`totalSupply()` before the mint). The mint is not blocked by `pause` or a frozen receiver (T-REX semantics). The
asset's LIVE state, freshness and the reserve cap all come through compliance (ADR 0014). **A mint blocked by
compliance surfaces as `TransferNotCompliant`**. The specific reason is named by the T6 pre-flight read (AC-21), not
by the revert (T0.6 Fix Spec §8).

**`burn(from, amount)` (agent):** if `amount` exceeds the free balance, unfreeze the shortfall from
`frozenTokens[from]` first and emit `TokensUnfrozen` (T-REX) → `_burn` → `compliance.destroyed`. Burns pass
`AssetLiveModule` (`from != 0`).

**Freeze (T3.2):** `setAddressFrozen` emits `AddressFrozen(wallet, frozen, msg.sender)`. `freezePartialTokens`
requires `frozen + amount ≤ balance` (`FreezeExceedsBalance`). `unfreezePartialTokens` requires `amount ≤ frozen`
(`UnfreezeExceedsFrozen`). `pause` / `unpause` revert on a no-op (`TokenAlreadyPaused` / `TokenNotPaused`), for the
same no-silent-no-op reason as `addAgent`.

## 4. `forcedTransfer`: multisig + timelock + reason code (T3.3, ADR 0015)

```solidity
uint64 public constant FORCED_TRANSFER_DELAY = 2 days;
enum ForcedTransferReason { COURT_ORDER, REGULATORY_ACTION, ERRONEOUS_TRANSFER, LOST_KEY_RECOVERY }

event ForcedTransferScheduled(bytes32 indexed id, address from, address to, uint256 amount, ForcedTransferReason reason, uint64 eta);
event ForcedTransferCancelled(bytes32 indexed id);
event ForcedTransferExecuted(bytes32 indexed id);

function scheduleForcedTransfer(address from, address to, uint256 amount, ForcedTransferReason reason) external; // owner
function cancelForcedTransfer(address from, address to, uint256 amount) external;                                 // owner
```

`id = keccak256(abi.encode(from, to, amount))`. Only one pending schedule per id (`ForcedTransferAlreadyScheduled`).
The IERC3643 `forcedTransfer(from, to, amount)` (owner) requires a schedule (`ForcedTransferNotScheduled`) whose
`eta ≤ block.timestamp` (`ForcedTransferTimelocked(id, eta)`). It deletes the schedule, requires `isVerified(to)`,
unfreezes the shortfall as `burn` does, moves the tokens **without** the pause, frozen-wallet or `canTransfer`
checks (T-REX forced semantics), calls `compliance.transferred`, and emits `ForcedTransferExecuted(id)`.
`batchForcedTransfer` applies the same rule to each element.

**Why 2 days is a constant:** the delay exists so a seizure is publicly visible before it happens. A setter for it
would be one more owner power to defend. Tests `vm.warp`. Changing it is a redeploy, as ADR 0025 intends.

## 5. `recoveryAddress`: owner-only, no timelock (Researcher call)

ADR 0015 names the timelock for `forcedTransfer` only. Recovery is requested by the investor who lost a key, and a
delay would hurt the person it protects. So `recoveryAddress(lost, new, investorOnchainID)` is **owner-only**
(multisig) with these guards:
- `identityRegistry.identity(lost) == investorOnchainID` (`RecoveryIdentityMismatch`).
- `investorOnchainID` holds `new` as a **management key** (purpose 1), which proves the investor consented
  (`RecoveryKeyNotOnIdentity`). This is the T-REX v4 rule.
- `balanceOf(lost) > 0` (`NothingToRecover`).

It moves the whole balance, carries over the frozen amount and the frozen flag, then calls
`identityRegistry.registerIdentity(new, investorOnchainID, country)` and `deleteIdentity(lost)`. **So the token must
be an agent of the IdentityRegistry**, which T5.1 grants. It emits `RecoverySuccess`.

## 6. T3.6: concrete acceptance suite

`contracts/test/tokens/ERC3643AcceptanceImpl.t.sol` subclasses `ERC3643AcceptanceTest` and overrides `deploySystem()`
with the **real** contracts (T1 + T2 + T4 + T4.3 + Token), not mocks. It wires exactly as T5.1 does (share a
`contracts/test/helpers/M3System.sol` builder with the T5.1 test). Because a mint now needs a LIVE, fresh, reserved
asset, the setup registers `gold-lot-001`, binds the token, submits an attestation with
`reserve = 999.9e18 × 10` (ample for 1,000e18 test mints), admits, and unpauses. All six inherited tests must pass
**unchanged**.

## 7. T4.5: the invariant, stated correctly

ADR 0019 §3 allows `totalSupply > reserve` after an honest downward re-attestation, so "supply ≤ reserve, always" is
**false by design** and would fail the fuzzer. The real property is **no mint ever creates supply beyond reserve**:

`contracts/test/invariant/AttestedSupplyLeReserve.t.sol`, handler actions: `mint`, `burn`, `transfer`,
`submitAndAdmit` (random reserve, random seq), `freeze`, `unfreeze`, `warp`.
- `invariant_noMintBeyondReserve`: a ghost counter of successful mints with `postSupply > reserveOf(asset)` at that
  moment stays at **0**.
- `invariant_supplyLeReserveWithoutDownwardAttestation`: while the handler has never admitted a reserve below the
  then-current supply, `totalSupply ≤ reserveOf`.
- `invariant_noMintWhileNotLiveOrStale`: a ghost counter of mints that succeeded while not LIVE or stale stays at
  **0**.

Run name for How-to-Run §4: `forge test --match-path test/invariant/AttestedSupplyLeReserve.t.sol`.

## 8. Unit test list (T3.1 to T3.4)

Each uses exact selectors. Gating: every owner and agent function against the wrong caller. Transfer path: each of the
six refusals in §3, in isolation. Mint path: `test_MintToUnverifiedReverts` (`ReceiverNotVerified`),
`test_MintWhenAssetPendingReverts`, `test_MintWhenAssetFrozenReverts`, `test_MintWhenReserveStaleReverts`,
`test_MintBeyondReserveReverts` (all `TransferNotCompliant(address(0), …)`), `test_TransferWhenAssetFrozenSucceeds`
(ADR 0019 §6). Forced: schedule → early execute reverts `ForcedTransferTimelocked` → warp → succeeds; cancel; double
schedule. Recovery: all three guards plus the happy path. Batch: length mismatch, cap of 100, and atomic all-or-nothing.

## 9. Acceptance criteria (the Researcher checks these)

- **AC-T3-1** §8 and §6 pass. The six acceptance tests run unmodified against the real suite.
- **AC-T3-2** `Token.sol` contains no reference to `IAssetRegistry`, `assetId` or `AssetLiveModule` (ADR 0014, by
  grep).
- **AC-T3-3** §7's three invariants hold at the default profile (1,000 runs) and are listed in How to Run §4.
- **AC-T3-4** `forge fmt --check` is clean. No `Ownable` / `AccessControl` / proxy imports.

## 10. Correction carried to T6 (recorded here, applied when T6.3 starts)

T6 spec AC-17's third test, `test_DirectTransferWhenAssetNotLiveReverts`, contradicts ADR 0019 §6: a transfer of a
non-LIVE asset **succeeds**. It becomes `test_DirectMintWhenAssetNotLiveReverts` →
`TransferNotCompliant(address(0), to, amount)`, plus `test_DirectTransferWhenAssetFrozenSucceeds` as the positive
twin. AC-17's first two tests expect `ReceiverNotVerified`, which matches §2.

Up: [[Tasks/T3 - ERC-3643 Token]] · Related: [[Specs/T1 - Identity Layer Build Spec]], [[Threads/Rounds/T2 - Researcher Rulings (round 1)]], [[Specs/T5.1 - Deploy Script Spec]]
