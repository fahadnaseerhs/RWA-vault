// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IIdentity} from "../vendor/onchain-id/interface/IIdentity.sol";
import {IClaimIssuer} from "../vendor/onchain-id/interface/IClaimIssuer.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {IIdentityRegistryStorage} from "./interfaces/IIdentityRegistryStorage.sol";
import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";
import {ITrustedIssuersRegistry} from "./interfaces/ITrustedIssuersRegistry.sol";

/**
 * @title IdentityRegistry
 * @notice The on-chain gatekeeper: answers "is this wallet allowed to hold the token?"
 * @dev Module 3, task T1.5. This is the contract the token calls on every mint and transfer.
 *      `isVerified(address)` walks from a wallet to its linked identity's claims, checking each
 *      required topic against the trusted issuers authorised **for that topic** — not globally.
 *
 *      The algorithm (T1 spec §7, [[Mathematics - Admission Predicate and Invariants]] §1):
 *
 *      1. id ← storage.storedIdentity(w);       none          → FALSE
 *      2. T  ← topicsRegistry.getClaimTopics();  T is empty    → FALSE (fail-closed, §4)
 *      3. For each topic t in T:
 *           claimIds ← id.getClaimIdsByTopic(t)
 *           For each claim c:
 *               if c.issuer trusted FOR t AND IClaimIssuer(c.issuer).isClaimValid(id, t, sig, data):
 *                   topic satisfied; break
 *           If NOT satisfied → FALSE (return early)
 *      4. return TRUE
 *
 *      The subtlety that breaks naive implementations is in step 3: issuers are fetched
 *      **per topic**, not globally. `isTrustedIssuer(issuer)` must never be used here.
 *
 *      Access model (ADR 0015, T1 spec §6):
 *      - `owner`: the 2-of-3 multisig. Owns the three registry setters — each can repoint the
 *        entire gate. Also sets the `agent`.
 *      - `agent`: the Tier 1 service key. Owns `registerIdentity`, `deleteIdentity`,
 *        `updateIdentity`, `updateCountry`, `batchRegisterIdentity`.
 *
 *      Plain deployment, constructor-wired, no initializer, no proxy (ADR 0025).
 *      NatSpec authored for RWA-Vault.
 */
contract IdentityRegistry is IIdentityRegistry {
    /**
     * @notice The owner (2-of-3 multisig, ADR 0015). Immutable, with no `transferOwnership`.
     * @dev See `ClaimTopicsRegistry` NatSpec for the in-multisig key rotation rationale.
     */
    address public immutable owner;

    /// @notice The agent (Tier 1 service key, ADR 0015). Settable by the owner.
    address public agent;

    /// @dev The backing identity storage (shared across tokens, ADR 0016).
    IIdentityRegistryStorage private _identityStorage;

    /// @dev The claim-topics registry.
    IClaimTopicsRegistry private _topicsRegistry;

    /// @dev The trusted-issuers registry.
    ITrustedIssuersRegistry private _issuersRegistry;

    // ── Errors ───────────────────────────────────────────────────────────────

    /// @notice An owner-only function was called by `caller`, who is not the owner.
    error NotOwner(address caller);

    /// @notice An agent-only function was called by `caller`, who is not the agent.
    error NotAuthorisedAgent(address caller);

    /// @notice The constructor was given `address(0)` as the owner.
    error InvalidOwner(address owner_);

    /// @notice `setAgent` was called with `address(0)`.
    error InvalidAgent(address agent_);

    /// @notice A wallet is not registered in the identity storage.
    error IdentityNotRegistered(address wallet);

    /// @notice An identity address has no deployed code (AC-T1-14).
    /// @dev The parameter's type is our `IIdentity`, but the argument is an upstream
    ///      `onchain-id` contract compiled separately. Compatibility rests on the ABI
    ///      rather than the type, and this no-code revert replaces the compiler's check.
    error IdentityHasNoCode(address identity);

    /// @notice `batchRegisterIdentity` arrays are not equal length.
    error ArrayLengthMismatch();

    /// @notice A registry-setter was called with `address(0)`.
    error InvalidAddress(address addr);

    // ── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyAgent() {
        if (msg.sender != agent) revert NotAuthorisedAgent(msg.sender);
        _;
    }

    // ── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param owner_ the 2-of-3 multisig. Must not be `address(0)`.
     * @param agent_ the Tier 1 service key. Must not be `address(0)`.
     * @param identityStorage_ the shared identity storage.
     * @param topicsRegistry_ the claim-topics registry.
     * @param issuersRegistry_ the trusted-issuers registry.
     */
    constructor(
        address owner_,
        address agent_,
        IIdentityRegistryStorage identityStorage_,
        IClaimTopicsRegistry topicsRegistry_,
        ITrustedIssuersRegistry issuersRegistry_
    ) {
        if (owner_ == address(0)) revert InvalidOwner(owner_);
        if (agent_ == address(0)) revert InvalidAgent(agent_);
        if (address(identityStorage_) == address(0)) revert InvalidAddress(address(identityStorage_));
        if (address(topicsRegistry_) == address(0)) revert InvalidAddress(address(topicsRegistry_));
        if (address(issuersRegistry_) == address(0)) revert InvalidAddress(address(issuersRegistry_));
        owner = owner_;
        agent = agent_;
        _identityStorage = identityStorage_;
        _topicsRegistry = topicsRegistry_;
        _issuersRegistry = issuersRegistry_;
    }

    // ── Agent operations ─────────────────────────────────────────────────────

    /// @inheritdoc IIdentityRegistry
    /// @dev Agent-only. The `_identity` parameter is typed as our `IIdentity`, but the
    ///      argument is an upstream `onchain-id` contract compiled separately at 0.8.17.
    ///      Compatibility rests on the ABI rather than the type; `extcodesize` is the
    ///      check that replaces the compiler's (AC-T1-14).
    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) external onlyAgent {
        if (address(_identity).code.length == 0) revert IdentityHasNoCode(address(_identity));
        _identityStorage.addIdentityToStorage(_userAddress, _identity, _country);
        emit IdentityRegistered(_userAddress, _identity);
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Agent-only. Reverts {IdentityNotRegistered} if the wallet is not stored.
    ///      Does not silently succeed on an unregistered wallet (AC-T1-31).
    function deleteIdentity(address _userAddress) external onlyAgent {
        IIdentity id = _identityStorage.storedIdentity(_userAddress);
        if (address(id) == address(0)) revert IdentityNotRegistered(_userAddress);
        _identityStorage.removeIdentityFromStorage(_userAddress);
        emit IdentityRemoved(_userAddress, id);
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Agent-only. Moves verification to the new identity in the same transaction:
    ///      the old identity's claims stop counting immediately (AC-T1-9).
    function updateIdentity(address _userAddress, IIdentity _identity) external onlyAgent {
        if (address(_identity).code.length == 0) revert IdentityHasNoCode(address(_identity));
        IIdentity old = _identityStorage.storedIdentity(_userAddress);
        if (address(old) == address(0)) revert IdentityNotRegistered(_userAddress);
        _identityStorage.modifyStoredIdentity(_userAddress, _identity);
        emit IdentityUpdated(old, _identity);
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Agent-only. Changes the country and does NOT affect `isVerified` (Q02 = A:
    ///      no country rule; AC-T1-10).
    function updateCountry(address _userAddress, uint16 _country) external onlyAgent {
        if (address(_identityStorage.storedIdentity(_userAddress)) == address(0)) {
            revert IdentityNotRegistered(_userAddress);
        }
        _identityStorage.modifyStoredInvestorCountry(_userAddress, _country);
        emit CountryUpdated(_userAddress, _country);
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Agent-only. All-or-nothing: if any registration fails (e.g. duplicate),
    ///      the entire batch reverts. A partial batch would leave an operator unable
    ///      to tell which half landed (AC-T1-30).
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    ) external onlyAgent {
        uint256 len = _userAddresses.length;
        if (len != _identities.length || len != _countries.length) revert ArrayLengthMismatch();
        for (uint256 i = 0; i < len; i++) {
            if (address(_identities[i]).code.length == 0) revert IdentityHasNoCode(address(_identities[i]));
            _identityStorage.addIdentityToStorage(_userAddresses[i], _identities[i], _countries[i]);
            emit IdentityRegistered(_userAddresses[i], _identities[i]);
        }
    }

    // ── Owner operations ─────────────────────────────────────────────────────

    /// @notice Sets the agent address. Owner-only.
    /// @param agent_ the new agent. Must not be `address(0)`.
    function setAgent(address agent_) external onlyOwner {
        if (agent_ == address(0)) revert InvalidAgent(agent_);
        agent = agent_;
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Owner-only. Can repoint the entire gate — sits where ADR 0015 puts registry setters.
    function setIdentityRegistryStorage(address _newIdentityStorage) external onlyOwner {
        if (_newIdentityStorage == address(0)) revert InvalidAddress(_newIdentityStorage);
        _identityStorage = IIdentityRegistryStorage(_newIdentityStorage);
        emit IdentityStorageSet(_newIdentityStorage);
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Owner-only.
    function setClaimTopicsRegistry(address _claimTopicsRegistry) external onlyOwner {
        if (_claimTopicsRegistry == address(0)) revert InvalidAddress(_claimTopicsRegistry);
        _topicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Owner-only.
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external onlyOwner {
        if (_trustedIssuersRegistry == address(0)) revert InvalidAddress(_trustedIssuersRegistry);
        _issuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }

    // ── Verification ─────────────────────────────────────────────────────────

    /// @inheritdoc IIdentityRegistry
    /// @dev The heart of ERC-3643 permissioning. See the algorithm in the contract-level
    ///      NatSpec. Returns false on an empty topic set as a fail-closed defence
    ///      (T1 spec §4, AC-T1-6), even though `ClaimTopicsRegistry`'s guards make it
    ///      unreachable. The cost of being wrong is every unverified wallet on earth
    ///      holding the token.
    function isVerified(address _userAddress) external view returns (bool) {
        // Step 1: wallet → identity. No identity → not verified.
        IIdentity id = _identityStorage.storedIdentity(_userAddress);
        if (address(id) == address(0)) return false;

        // Step 2: required topics. Empty → false (fail-closed, AC-T1-6).
        uint256[] memory topics = _topicsRegistry.getClaimTopics();
        if (topics.length == 0) return false;

        // Step 3: for each required topic, find at least one valid claim from a trusted issuer.
        for (uint256 i = 0; i < topics.length; i++) {
            uint256 topic = topics[i];
            bytes32[] memory claimIds = id.getClaimIdsByTopic(topic);

            bool satisfied = false;
            for (uint256 j = 0; j < claimIds.length; j++) {
                // Get the claim's fields from the identity.
                (uint256 claimTopic,, address issuer, bytes memory sig, bytes memory data,) = id.getClaim(claimIds[j]);

                // The issuer must be trusted FOR THIS TOPIC, not merely trusted.
                // Using `hasClaimTopic` rather than `isTrustedIssuer` is what makes
                // AC-T1-7 pass and a naive implementation fail.
                if (claimTopic != topic) continue;
                if (!_issuersRegistry.hasClaimTopic(issuer, topic)) continue;

                // The claim issuer validates the signature and revocation status.
                try IClaimIssuer(issuer).isClaimValid(id, topic, sig, data) returns (bool valid) {
                    if (valid) {
                        satisfied = true;
                        break;
                    }
                } catch {
                    // A broken issuer contract must not pass verification — fail closed.
                    continue;
                }
            }

            // Any unsatisfied topic → not verified (return early).
            if (!satisfied) return false;
        }

        // Step 4: every topic satisfied.
        return true;
    }

    // ── Read accessors ───────────────────────────────────────────────────────

    /// @inheritdoc IIdentityRegistry
    function contains(address _userAddress) external view returns (bool) {
        return address(_identityStorage.storedIdentity(_userAddress)) != address(0);
    }

    /// @inheritdoc IIdentityRegistry
    function identity(address _userAddress) external view returns (IIdentity) {
        return _identityStorage.storedIdentity(_userAddress);
    }

    /// @inheritdoc IIdentityRegistry
    function investorCountry(address _userAddress) external view returns (uint16) {
        return _identityStorage.storedInvestorCountry(_userAddress);
    }

    /// @inheritdoc IIdentityRegistry
    function identityStorage() external view returns (IIdentityRegistryStorage) {
        return _identityStorage;
    }

    /// @inheritdoc IIdentityRegistry
    function issuersRegistry() external view returns (ITrustedIssuersRegistry) {
        return _issuersRegistry;
    }

    /// @inheritdoc IIdentityRegistry
    function topicsRegistry() external view returns (IClaimTopicsRegistry) {
        return _topicsRegistry;
    }
}
