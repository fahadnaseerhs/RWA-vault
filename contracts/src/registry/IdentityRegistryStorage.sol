// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import {IIdentity} from "../vendor/onchain-id/interface/IIdentity.sol";
import {IIdentityRegistryStorage} from "./interfaces/IIdentityRegistryStorage.sol";

/**
 * @title IdentityRegistryStorage
 * @notice The shared address book: (wallet → identity, country) records.
 * @dev Module 3, task T1.5. Separated from `IdentityRegistry` so that several tokens'
 *      registries can read one canonical investor set (ADR 0016). One investor KYC'd
 *      once should hold every asset we ever tokenise without re-registering. Only
 *      Identity Registries that are explicitly bound by the owner may write.
 *
 *      Plain deployment, constructor-wired, no initializer, no proxy (ADR 0025). Owner
 *      is the 2-of-3 multisig (ADR 0015), checked with a named error rather than
 *      OpenZeppelin `Ownable` so the onboarding script can translate it (T1 spec §6).
 *      NatSpec authored for RWA-Vault.
 */
contract IdentityRegistryStorage is IIdentityRegistryStorage {
    /**
     * @notice The owner (2-of-3 multisig, ADR 0015). Immutable, with no `transferOwnership`.
     * @dev See `ClaimTopicsRegistry` NatSpec for the in-multisig key rotation rationale.
     */
    address public immutable owner;

    // ── Storage ──────────────────────────────────────────────────────────────

    /// @dev wallet → identity contract.
    mapping(address => IIdentity) private _identities;

    /// @dev wallet → ISO-3166 country code.
    mapping(address => uint16) private _countries;

    /// @dev wallet → is registered? Used because a zero identity is indistinguishable from "not stored".
    mapping(address => bool) private _registered;

    // ── Bound registries ─────────────────────────────────────────────────────

    /// @dev All bound Identity Registries, for `linkedIdentityRegistries()`.
    address[] private _boundRegistries;

    /// @dev registry address → 1-based index in `_boundRegistries` (0 = not bound).
    mapping(address => uint256) private _registryIndex;

    // ── Errors ───────────────────────────────────────────────────────────────

    /// @notice An owner-only function was called by `caller`, who is not the owner.
    error NotOwner(address caller);

    /// @notice The constructor was given `address(0)` as the owner.
    error InvalidOwner(address owner_);

    /// @notice A storage-mutating function was called by a registry that is not bound.
    error NotBoundRegistry(address caller);

    /// @notice `addIdentityToStorage` for a wallet that already has an identity stored.
    error IdentityAlreadyStored(address wallet);

    /// @notice A mutator was called for a wallet with no stored identity.
    error IdentityNotStored(address wallet);

    /// @notice `bindIdentityRegistry` for a registry that is already bound.
    error RegistryAlreadyBound(address registry);

    /// @notice `unbindIdentityRegistry` for a registry that is not bound.
    error RegistryNotBound(address registry);

    /// @notice A registry address was `address(0)`.
    error InvalidRegistry(address registry);

    /// @notice An identity address has no deployed code (AC-T1-14 defense in depth).
    error IdentityHasNoCode(address identity);

    // ── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyBoundRegistry() {
        if (_registryIndex[msg.sender] == 0) revert NotBoundRegistry(msg.sender);
        _;
    }

    // ── Constructor ──────────────────────────────────────────────────────────

    /// @param owner_ the 2-of-3 multisig. Must not be `address(0)`.
    constructor(address owner_) {
        if (owner_ == address(0)) revert InvalidOwner(owner_);
        owner = owner_;
    }

    // ── Identity storage mutations (bound registries only) ───────────────────

    /// @inheritdoc IIdentityRegistryStorage
    /// @dev Called by a bound `IdentityRegistry`. Reverts {IdentityAlreadyStored} or
    ///      {IdentityHasNoCode}.
    function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country)
        external
        onlyBoundRegistry
    {
        if (_registered[_userAddress]) revert IdentityAlreadyStored(_userAddress);
        if (address(_identity).code.length == 0) revert IdentityHasNoCode(address(_identity));
        _identities[_userAddress] = _identity;
        _countries[_userAddress] = _country;
        _registered[_userAddress] = true;
        emit IdentityStored(_userAddress, _identity);
    }

    /// @inheritdoc IIdentityRegistryStorage
    /// @dev Called by a bound `IdentityRegistry`. Reverts {IdentityNotStored}.
    function removeIdentityFromStorage(address _userAddress) external onlyBoundRegistry {
        if (!_registered[_userAddress]) revert IdentityNotStored(_userAddress);
        IIdentity id = _identities[_userAddress];
        delete _identities[_userAddress];
        delete _countries[_userAddress];
        delete _registered[_userAddress];
        emit IdentityUnstored(_userAddress, id);
    }

    /// @inheritdoc IIdentityRegistryStorage
    /// @dev Called by a bound `IdentityRegistry`. Reverts {IdentityNotStored}.
    function modifyStoredInvestorCountry(address _userAddress, uint16 _country) external onlyBoundRegistry {
        if (!_registered[_userAddress]) revert IdentityNotStored(_userAddress);
        _countries[_userAddress] = _country;
        emit CountryModified(_userAddress, _country);
    }

    /// @inheritdoc IIdentityRegistryStorage
    /// @dev Called by a bound `IdentityRegistry`. Reverts {IdentityNotStored} or
    ///      {IdentityHasNoCode}.
    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external onlyBoundRegistry {
        if (!_registered[_userAddress]) revert IdentityNotStored(_userAddress);
        if (address(_identity).code.length == 0) revert IdentityHasNoCode(address(_identity));
        IIdentity old = _identities[_userAddress];
        _identities[_userAddress] = _identity;
        emit IdentityModified(old, _identity);
    }

    // ── Binding (owner-only) ─────────────────────────────────────────────────

    /// @inheritdoc IIdentityRegistryStorage
    /// @dev Owner-only. Reverts {InvalidRegistry} or {RegistryAlreadyBound}.
    function bindIdentityRegistry(address _identityRegistry) external onlyOwner {
        if (_identityRegistry == address(0)) revert InvalidRegistry(_identityRegistry);
        if (_registryIndex[_identityRegistry] != 0) revert RegistryAlreadyBound(_identityRegistry);
        _boundRegistries.push(_identityRegistry);
        _registryIndex[_identityRegistry] = _boundRegistries.length; // 1-based
        emit IdentityRegistryBound(_identityRegistry);
    }

    /// @inheritdoc IIdentityRegistryStorage
    /// @dev Owner-only. Reverts {RegistryNotBound}.
    function unbindIdentityRegistry(address _identityRegistry) external onlyOwner {
        uint256 idx = _registryIndex[_identityRegistry];
        if (idx == 0) revert RegistryNotBound(_identityRegistry);

        uint256 lastIdx = _boundRegistries.length;
        if (idx != lastIdx) {
            address last = _boundRegistries[lastIdx - 1];
            _boundRegistries[idx - 1] = last;
            _registryIndex[last] = idx;
        }
        _boundRegistries.pop();
        delete _registryIndex[_identityRegistry];

        emit IdentityRegistryUnbound(_identityRegistry);
    }

    // ── Views ────────────────────────────────────────────────────────────────

    /// @inheritdoc IIdentityRegistryStorage
    function linkedIdentityRegistries() external view returns (address[] memory) {
        return _boundRegistries;
    }

    /// @inheritdoc IIdentityRegistryStorage
    function storedIdentity(address _userAddress) external view returns (IIdentity) {
        return _identities[_userAddress];
    }

    /// @inheritdoc IIdentityRegistryStorage
    function storedInvestorCountry(address _userAddress) external view returns (uint16) {
        return _countries[_userAddress];
    }
}
