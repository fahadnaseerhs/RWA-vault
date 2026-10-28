// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAssetRegistry, MAX_VALUATION_WINDOW} from "./interfaces/IAssetRegistry.sol";
import {IReserveAttestationSource} from "./interfaces/IReserveAttestationSource.sol";

/**
 * @title AssetRegistry
 * @notice The on-chain lifecycle of a real-world asset and its admission predicate
 *         (clauses 2-4; clause 1 is checked by the attestation source, ADR 0017/0027).
 * @dev Plain, immutable deployment (ADR 0025): the owner is fixed at construction and there
 *      is no proxy. Behaviour follows ADR 0019:
 *        1. a failed `admit` reverts and writes nothing; the asset stays PENDING;
 *        2. a LIVE asset may be re-attested and stays LIVE;
 *        3. a re-attestation below current supply is accepted and emits `UnderReserve`;
 *           the mint cap itself lives in the compliance module (ADR 0014);
 *        4. `freeze` is agent, `unfreeze` is owner.
 *      Attested supply is always derived from the bound token's `totalSupply()`.
 */
contract AssetRegistry is IAssetRegistry {
    /// @notice The 2-of-3 governance multisig (ADR 0015). Fixed for the life of the contract.
    address public immutable owner;

    mapping(bytes32 => AssetState) private _state;
    mapping(bytes32 => uint256) private _reserve;
    mapping(bytes32 => uint64) private _lastSeq;
    mapping(bytes32 => bytes32) private _metadataHash;
    mapping(bytes32 => string) private _assetRef;
    mapping(bytes32 => address) private _tokenOf;
    mapping(address => bytes32) private _assetOfToken;
    mapping(bytes32 => uint64) private _windowFor;
    mapping(address => bool) private _agents;

    uint64 private _globalWindow;
    address private _source;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyAgent() {
        if (!_agents[msg.sender]) revert NotAuthorisedAgent(msg.sender);
        _;
    }

    /// @param owner_ the governance multisig; must not be `address(0)`.
    constructor(address owner_) {
        if (owner_ == address(0)) revert NotOwner(address(0));
        owner = owner_;
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @inheritdoc IAssetRegistry
    function stateOf(bytes32 assetId) external view returns (AssetState) {
        return _state[assetId];
    }

    /// @inheritdoc IAssetRegistry
    function isLive(bytes32 assetId) external view returns (bool) {
        return _state[assetId] == AssetState.LIVE;
    }

    /// @inheritdoc IAssetRegistry
    function reserveOf(bytes32 assetId) external view returns (uint256) {
        return _reserve[assetId];
    }

    /// @inheritdoc IAssetRegistry
    function attestedSupplyOf(bytes32 assetId) external view returns (uint256) {
        address token = _tokenOf[assetId];
        if (token == address(0)) revert TokenNotBound(assetId);
        return IERC20(token).totalSupply();
    }

    /// @inheritdoc IAssetRegistry
    function lastSequenceOf(bytes32 assetId) external view returns (uint64) {
        return _lastSeq[assetId];
    }

    /// @inheritdoc IAssetRegistry
    function metadataHashOf(bytes32 assetId) external view returns (bytes32) {
        return _metadataHash[assetId];
    }

    /// @inheritdoc IAssetRegistry
    function assetRefOf(bytes32 assetId) external view returns (string memory) {
        return _assetRef[assetId];
    }

    /// @inheritdoc IAssetRegistry
    function tokenOf(bytes32 assetId) external view returns (address) {
        return _tokenOf[assetId];
    }

    /// @inheritdoc IAssetRegistry
    function assetOfToken(address token) external view returns (bytes32) {
        return _assetOfToken[token];
    }

    /// @inheritdoc IAssetRegistry
    function valuationWindowOf(bytes32 assetId) public view returns (uint64) {
        uint64 w = _windowFor[assetId];
        return w != 0 ? w : _globalWindow;
    }

    /// @inheritdoc IAssetRegistry
    function attestationSource() external view returns (address) {
        return _source;
    }

    /// @inheritdoc IAssetRegistry
    function isAgent(address account) external view returns (bool) {
        return _agents[account];
    }

    // ------------------------------------------------------------------
    // Agent
    // ------------------------------------------------------------------

    /// @inheritdoc IAssetRegistry
    function register(bytes32 assetId, bytes32 metadataHash, string calldata assetRef) external onlyAgent {
        if (assetId == bytes32(0)) revert EmptyAssetId();
        if (_state[assetId] != AssetState.UNREGISTERED) revert AssetAlreadyRegistered(assetId);

        _state[assetId] = AssetState.PENDING;
        _metadataHash[assetId] = metadataHash;
        _assetRef[assetId] = assetRef;
        emit AssetRegistered(assetId, assetRef, metadataHash);
    }

    /**
     * @inheritdoc IAssetRegistry
     * @dev Check order follows the provider flow (Decision Algorithms A.4): identity
     *      cross-check, clause 2 (sequence), clause 3 (reserve, first admission only),
     *      clause 4 (future timestamp first, then staleness). On a LIVE asset clause 3 is
     *      replaced by the ADR 0019 §3 under-reserve signal: the figure is accepted and
     *      `UnderReserve` is emitted, and `intendedSupply` is ignored.
     */
    function admit(bytes32 assetId, uint256 intendedSupply) external onlyAgent {
        AssetState s = _state[assetId];
        if (s == AssetState.UNREGISTERED) revert AssetNotRegistered(assetId);
        if (s == AssetState.FROZEN) revert AssetNotLive(assetId, s);

        address source = _source;
        if (source == address(0) || !IReserveAttestationSource(source).hasAttestation(assetId)) {
            revert NoAttestation(assetId);
        }
        IReserveAttestationSource.ReserveAttestation memory a = IReserveAttestationSource(source).latest(assetId);

        if (a.assetId != assetId) revert AssetIdMismatch(assetId, a.assetId);

        // Clause 2 — strictly monotonic sequence.
        uint64 last = _lastSeq[assetId];
        if (a.seq <= last) revert StaleSequence(a.seq, last);

        // Clause 3 — first admission only; a re-attestation is judged against current supply below.
        if (s == AssetState.PENDING && a.reserve < intendedSupply) revert ReserveTooLow(a.reserve, intendedSupply);

        // Clause 4 — fresh and not from the future. A zero window rejects everything.
        uint64 nowTs = uint64(block.timestamp);
        if (a.valuationTs > nowTs) revert ValuationInFuture(a.valuationTs, nowTs);
        uint64 window = valuationWindowOf(assetId);
        if (window == 0 || nowTs - a.valuationTs > window) revert ValuationStale(a.valuationTs, window);

        _reserve[assetId] = a.reserve;
        _lastSeq[assetId] = a.seq;
        if (s == AssetState.PENDING) _state[assetId] = AssetState.LIVE;
        emit AssetAdmitted(assetId, a.reserve, a.seq, a.valuationTs);

        if (s == AssetState.LIVE) {
            address token = _tokenOf[assetId];
            uint256 supply = token == address(0) ? 0 : IERC20(token).totalSupply();
            if (a.reserve < supply) emit UnderReserve(assetId, a.reserve, supply);
        }
    }

    /// @inheritdoc IAssetRegistry
    function freeze(bytes32 assetId, string calldata reason) external onlyAgent {
        AssetState s = _state[assetId];
        if (s == AssetState.UNREGISTERED) revert AssetNotRegistered(assetId);
        if (s != AssetState.LIVE) revert AssetNotLive(assetId, s);

        _state[assetId] = AssetState.FROZEN;
        emit AssetFrozen(assetId, reason);
    }

    // ------------------------------------------------------------------
    // Owner
    // ------------------------------------------------------------------

    /// @inheritdoc IAssetRegistry
    function unfreeze(bytes32 assetId) external onlyOwner {
        AssetState s = _state[assetId];
        if (s == AssetState.UNREGISTERED) revert AssetNotRegistered(assetId);
        if (s != AssetState.FROZEN) revert AssetNotFrozen(assetId);

        _state[assetId] = AssetState.LIVE;
        emit AssetUnfrozen(assetId);
    }

    /// @inheritdoc IAssetRegistry
    function setValuationWindow(uint64 seconds_) external onlyOwner {
        if (seconds_ == 0 || seconds_ > MAX_VALUATION_WINDOW) revert InvalidValuationWindow(seconds_);
        _globalWindow = seconds_;
        emit ValuationWindowSet(seconds_);
    }

    /// @inheritdoc IAssetRegistry
    function setValuationWindowFor(bytes32 assetId, uint64 seconds_) external onlyOwner {
        if (seconds_ == 0 || seconds_ > MAX_VALUATION_WINDOW) revert InvalidValuationWindow(seconds_);
        _windowFor[assetId] = seconds_;
        emit ValuationWindowSetFor(assetId, seconds_);
    }

    /// @inheritdoc IAssetRegistry
    function setAttestationSource(address source) external onlyOwner {
        if (source == address(0) || source.code.length == 0) revert InvalidAttestationSource(source);
        _source = source;
        emit AttestationSourceSet(source);
    }

    /// @inheritdoc IAssetRegistry
    function setTokenFor(bytes32 assetId, address token) external onlyOwner {
        if (_state[assetId] == AssetState.UNREGISTERED) revert AssetNotRegistered(assetId);
        if (token == address(0)) revert InvalidTokenBinding(token);
        address current = _tokenOf[assetId];
        if (current != address(0)) revert AssetAlreadyHasToken(assetId, current);
        bytes32 other = _assetOfToken[token];
        if (other != bytes32(0)) revert TokenAlreadyBound(token, other);

        _tokenOf[assetId] = token;
        _assetOfToken[token] = assetId;
        emit AssetTokenBound(assetId, token);
    }

    /// @inheritdoc IAssetRegistry
    function addAgent(address account) external onlyOwner {
        if (account == address(0)) revert InvalidAgent(account);
        if (_agents[account]) revert AgentUnchanged(account);
        _agents[account] = true;
        emit AgentAdded(account);
    }

    /// @inheritdoc IAssetRegistry
    function removeAgent(address account) external onlyOwner {
        if (account == address(0)) revert InvalidAgent(account);
        if (!_agents[account]) revert AgentUnchanged(account);
        _agents[account] = false;
        emit AgentRemoved(account);
    }
}
