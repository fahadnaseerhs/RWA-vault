// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @dev Upper bound on any clause 4 valuation-freshness window, global or per asset.
 *      File-level because an interface cannot hold a constant. Implementations validate
 *      both window setters against THIS constant, never a literal of their own, so the
 *      documented bound and the enforced bound are one value (T0.6 Fix Spec §14.4).
 */
uint64 constant MAX_VALUATION_WINDOW = 365 days;

/**
 * @title IAssetRegistry
 * @notice The on-chain lifecycle of a real-world asset: answers "may anyone mint
 *         against this asset, right now?".
 * @dev The asset half of Module 3 (ERC-3643 answers "who may hold"; this answers
 *      "may a token for this asset exist"). States move only as:
 *
 *        UNREGISTERED --register--> PENDING --admit--> LIVE --freeze--> FROZEN
 *                                              LIVE --admit--> LIVE (re-attestation)
 *                                            FROZEN --unfreeze--> LIVE
 *
 *      A failed `admit` reverts and leaves the asset PENDING. Reserve data is read
 *      from an {IReserveAttestationSource}; `admit` takes no envelope (ADR 0017).
 *      The token never calls this contract (ADR 0014): attested supply is derived
 *      from the bound token's `totalSupply()`, and the mint cap
 *      `totalSupply + amount <= reserve` is enforced by the compliance module, not
 *      here. Asset ids are `keccak256(bytes(slug))`. Roles per ADR 0015: `agent` is
 *      the Tier 1 service key, `owner` the 2-of-3 multisig; `freeze` is agent but
 *      `unfreeze` is owner (ADR 0019). NatSpec for RWA-Vault.
 */
interface IAssetRegistry {
    /**
     * @notice Asset lifecycle state. UNREGISTERED is index 0, so an unknown id reads
     *         as UNREGISTERED from zeroed storage. Order matches `AssetStatus` in
     *         `@rwa-vault/types`.
     */
    enum AssetState {
        UNREGISTERED,
        PENDING,
        LIVE,
        FROZEN
    }

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    /// @notice Emitted on UNREGISTERED -> PENDING, with the human slug and committed metadata.
    event AssetRegistered(bytes32 indexed assetId, string assetRef, bytes32 metadataHash);

    /// @notice Emitted when an attestation is accepted by `admit` (first admission or re-attestation).
    event AssetAdmitted(bytes32 indexed assetId, uint256 reserve, uint64 seq, uint64 valuationTs);

    /// @notice Emitted on LIVE -> FROZEN.
    event AssetFrozen(bytes32 indexed assetId, string reason);

    /// @notice Emitted on FROZEN -> LIVE.
    event AssetUnfrozen(bytes32 indexed assetId);

    /**
     * @notice Emitted when an accepted re-attestation's reserve is below current supply.
     * @dev Further mints are blocked; freezing is left to an operator (Q14, Option B).
     */
    event UnderReserve(bytes32 indexed assetId, uint256 reserve, uint256 attestedSupply);

    /// @notice Emitted when the owner sets the global valuation-freshness window.
    event ValuationWindowSet(uint64 seconds_);

    /// @notice Emitted when the owner sets a per-asset valuation-freshness override.
    event ValuationWindowSetFor(bytes32 indexed assetId, uint64 seconds_);

    /// @notice Emitted when the owner sets the reserve attestation source (MS1 envelope source, later M5).
    event AttestationSourceSet(address source);

    /**
     * @notice Emitted when the owner binds an asset to its token (ADR 0016: one token per asset).
     * @dev Named `AssetTokenBound`, not `TokenBound`, so it never shares a name with
     *      `IModularCompliance.TokenBound(address)` in a merged ABI.
     */
    event AssetTokenBound(bytes32 indexed assetId, address token);

    /// @notice Emitted when the owner grants the agent role (ADR 0015).
    event AgentAdded(address indexed account);

    /// @notice Emitted when the owner revokes the agent role (ADR 0015).
    event AgentRemoved(address indexed account);

    // ------------------------------------------------------------------
    // Errors — admission predicate, clauses 2-4 (clause 1 is on the source)
    // ------------------------------------------------------------------

    /**
     * @notice Clause 2: the attestation's sequence is not strictly greater than the last accepted.
     * @dev Raised by `admit` (agent).
     */
    error StaleSequence(uint64 submitted, uint64 lastAccepted);

    /**
     * @notice Clause 3: the attested reserve is below the supply required.
     * @dev Raised by `admit` (agent): against `intendedSupply` on first admission,
     *      against current supply on re-attestation.
     */
    error ReserveTooLow(uint256 reserve, uint256 required);

    /**
     * @notice Clause 4: `block.timestamp - valuationTs` exceeds the asset's window. No grace.
     * @dev Raised by `admit` (agent). `window` is {valuationWindowOf} for the asset.
     */
    error ValuationStale(uint64 valuationTs, uint64 window);

    /**
     * @notice Clause 4 precondition: the attestation's `valuationTs` is after `block.timestamp`.
     * @dev Raised by `admit` (agent) BEFORE the clause 4 subtraction, so a future
     *      timestamp is a named rejection, never a `Panic(0x11)` underflow. No skew tolerance.
     */
    error ValuationInFuture(uint64 valuationTs, uint64 blockTime);

    // ------------------------------------------------------------------
    // Errors — state machine
    // ------------------------------------------------------------------

    /// @notice The asset is UNREGISTERED; raised by `admit`/`freeze` (agent) and `unfreeze`/`setTokenFor` (owner).
    error AssetNotRegistered(bytes32 assetId);

    /// @notice `register` (agent) on an asset that is not UNREGISTERED.
    error AssetAlreadyRegistered(bytes32 assetId);

    /// @notice `freeze` (agent) or a re-attestation on an asset that is not LIVE; carries the actual state.
    error AssetNotLive(bytes32 assetId, AssetState state);

    /// @notice `unfreeze` (owner) on an asset that is not FROZEN (FROZEN -> LIVE only).
    error AssetNotFrozen(bytes32 assetId);

    /// @notice `register` (agent) with `assetId == bytes32(0)`, which would alias the unregistered default.
    error EmptyAssetId();

    // ------------------------------------------------------------------
    // Errors — wiring and authority
    // ------------------------------------------------------------------

    /// @notice `admit` (agent) when the source has no attestation for the asset; a zeroed struct is never read as a 0 reserve.
    error NoAttestation(bytes32 assetId);

    /// @notice {attestedSupplyOf} (or any operation needing the asset's token) before `setTokenFor` (owner) bound one.
    error TokenNotBound(bytes32 assetId);

    /// @notice An agent-only function called by an address that is not an agent (ADR 0015).
    error NotAuthorisedAgent(address caller);

    /**
     * @notice An owner-only function called by an address that is not the owner (ADR 0015).
     * @dev Declared here instead of inheriting OpenZeppelin `Ownable`, whose
     *      `OwnableUnauthorizedAccount` is not in the T6 §3.4 translation table.
     */
    error NotOwner(address caller);

    /// @notice `addAgent` / `removeAgent` (owner) with `address(0)`.
    error InvalidAgent(address account);

    /// @notice `addAgent` (owner) on an existing agent, or `removeAgent` (owner) on a non-agent; never a silent no-op.
    error AgentUnchanged(address account);

    /// @notice `setValuationWindow` / `setValuationWindowFor` (owner) outside `0 < seconds_ <= MAX_VALUATION_WINDOW`.
    error InvalidValuationWindow(uint64 seconds_);

    /// @notice `setAttestationSource` (owner) with an unusable source (e.g. `address(0)`).
    error InvalidAttestationSource(address source);

    /**
     * @notice `admit` (agent): the attestation returned by `latest(assetId)` carries a
     *         different `assetId` than the one being admitted.
     * @dev Guards the ADR 0017 seam against a wrongly keyed source implementation (ADR 0019).
     */
    error AssetIdMismatch(bytes32 expected, bytes32 fromAttestation);

    /// @notice `setTokenFor` (owner) with a token already bound to another asset (one token -> two assets).
    error TokenAlreadyBound(address token, bytes32 assetId);

    /// @notice `setTokenFor` (owner) on an asset that already has a token; re-binding is forbidden (ADR 0016).
    error AssetAlreadyHasToken(bytes32 assetId, address token);

    /// @notice `setTokenFor` (owner) with `address(0)`; unbinding has no use case.
    error InvalidTokenBinding(address token);

    // ------------------------------------------------------------------
    // Views — anyone may call
    // ------------------------------------------------------------------

    /// @notice Returns the asset's lifecycle state; UNREGISTERED for an unknown id. Anyone may call.
    function stateOf(bytes32 assetId) external view returns (AssetState);

    /// @notice Returns true iff the asset is LIVE. Anyone may call. Read by the compliance module; only mints are vetoed.
    function isLive(bytes32 assetId) external view returns (bool);

    /**
     * @notice Returns the reserve from the last accepted attestation. Anyone may call.
     * @dev `reserve`, `intendedSupply` and `attestedSupply` are all in the token's own base
     *      units and must never be mixed with any other measure of the same asset. For gold
     *      that unit is fine grams x 10^18 (ADR 0020); gross weight never appears.
     */
    function reserveOf(bytes32 assetId) external view returns (uint256);

    /**
     * @notice Returns the tokens in existence for the asset. Anyone may call.
     * @dev Derived as `IERC20(tokenOf(assetId)).totalSupply()`; never a stored counter
     *      (ADR 0014, 0016). Reverts `TokenNotBound` when no token is bound, because 0
     *      would be indistinguishable from "nothing minted yet"; callers check
     *      {tokenOf} (or {stateOf}) first.
     */
    function attestedSupplyOf(bytes32 assetId) external view returns (uint256);

    /// @notice Returns the sequence of the last accepted attestation (the clause 2 replay guard). Anyone may call.
    function lastSequenceOf(bytes32 assetId) external view returns (uint64);

    /// @notice Returns the metadata hash committed at `register`. Anyone may call.
    function metadataHashOf(bytes32 assetId) external view returns (bytes32);

    /// @notice Returns the human slug stored at `register`, e.g. "gold-lot-001". Anyone may call.
    function assetRefOf(bytes32 assetId) external view returns (string memory);

    /// @notice Returns the token bound to the asset, or `address(0)` if none. Anyone may call.
    function tokenOf(bytes32 assetId) external view returns (address);

    /**
     * @notice Returns the asset bound to `token`, or `bytes32(0)` if none. Anyone may call.
     * @dev The compliance module's only route from a token to its asset. The zero return
     *      for an unbound token is INTENDED: `stateOf(bytes32(0))` is UNREGISTERED and
     *      `isLive` is false, so the module fails closed and refuses the mint. Do not
     *      change this into a revert.
     */
    function assetOfToken(address token) external view returns (bytes32);

    /**
     * @notice Returns the clause 4 freshness window for the asset: its override if set, else the global default. Anyone may call.
     * @dev If neither is set the window is 0, which rejects every admission. That fails
     *      closed by design, not by accident of zero-initialisation: no asset can go LIVE
     *      until the owner has chosen a window.
     */
    function valuationWindowOf(bytes32 assetId) external view returns (uint64);

    /// @notice Returns the current reserve attestation source. Anyone may call.
    function attestationSource() external view returns (address);

    /// @notice Returns true if `account` holds the agent role (ADR 0015). Anyone may call.
    function isAgent(address account) external view returns (bool);

    // ------------------------------------------------------------------
    // State-changing — agent (Tier 1 service key, ADR 0015)
    // ------------------------------------------------------------------

    /**
     * @notice UNREGISTERED -> PENDING. Agent-only.
     * @param assetId `keccak256(bytes(assetRef))`.
     * @param metadataHash computed by the caller from the onboarding input (T6.0 answers A2).
     * @param assetRef the human slug, stored and emitted.
     */
    function register(bytes32 assetId, bytes32 metadataHash, string calldata assetRef) external;

    /**
     * @notice PENDING -> LIVE, or LIVE -> LIVE on re-attestation. Agent-only.
     * @dev Reads the attestation from {attestationSource}, requires its `assetId` to
     *      match (else `AssetIdMismatch`), then checks clauses 2-4.
     *      Reverts with the clause's error and writes nothing on failure.
     * @param intendedSupply the supply clause 3 must cover on first admission. `reserve`,
     *        `intendedSupply` and `attestedSupply` are all in the token's own base units and
     *        must never be mixed with any other measure of the same asset. For gold that
     *        unit is fine grams x 10^18 (ADR 0020); gross weight never appears.
     */
    function admit(bytes32 assetId, uint256 intendedSupply) external;

    /**
     * @notice LIVE -> FROZEN; minting stops, transfers continue (ADR 0019 d.6). Agent-only.
     * @dev Deliberately the cheap brake: an agent can halt minting during an incident
     *      without waiting for the multisig. Releasing it is owner-only ({unfreeze}).
     */
    function freeze(bytes32 assetId, string calldata reason) external;

    // ------------------------------------------------------------------
    // Admin — owner (2-of-3 multisig, ADR 0015)
    // ------------------------------------------------------------------

    /**
     * @notice FROZEN -> LIVE. Owner-only (governance, per `AssetStatus` in `@rwa-vault/types`).
     * @dev The expensive release: unfreezing wrongly resumes minting against a possibly
     *      stale reserve, so it needs the multisig while {freeze} does not (ADR 0019).
     */
    function unfreeze(bytes32 assetId) external;

    /// @notice Sets the global default clause 4 window, in seconds; requires `0 < seconds_ <= MAX_VALUATION_WINDOW`. Owner-only.
    function setValuationWindow(uint64 seconds_) external;

    /// @notice Sets a per-asset clause 4 window override, in seconds; requires `0 < seconds_ <= MAX_VALUATION_WINDOW`. Owner-only.
    function setValuationWindowFor(bytes32 assetId, uint64 seconds_) external;

    /// @notice Sets the reserve attestation source (the MS1 -> M5 swap point). Owner-only.
    function setAttestationSource(address source) external;

    /**
     * @notice Binds the asset to its token, one to one (ADR 0016). Owner-only.
     * @dev Rejects `address(0)` (`InvalidTokenBinding`), a token already bound to another
     *      asset (`TokenAlreadyBound`) and an asset that already has a token
     *      (`AssetAlreadyHasToken`). A token migration needs an ADR, not this setter.
     */
    function setTokenFor(bytes32 assetId, address token) external;

    /**
     * @notice Grants the agent role to `account`. Owner-only (ADR 0015).
     * @dev Not idempotent: reverts `InvalidAgent` for `address(0)` and `AgentUnchanged` if
     *      `account` is already an agent. This is a 2-of-3 multisig action, and a silent
     *      no-op would mean the multisig signed a change that did nothing, emitted no
     *      event and left no way to tell whether the intended change happened.
     */
    function addAgent(address account) external;

    /**
     * @notice Revokes the agent role from `account`. Owner-only (ADR 0015).
     * @dev Not idempotent: reverts `InvalidAgent` for `address(0)` and `AgentUnchanged` if
     *      `account` is not an agent, for the same multisig reason as {addAgent}.
     */
    function removeAgent(address account) external;
}
