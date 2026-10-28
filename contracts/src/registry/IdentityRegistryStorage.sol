// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IIdentityRegistryStorage} from "./interfaces/IIdentityRegistryStorage.sol";
import {IIdentity} from "../identity/interfaces/IIdentity.sol";

/**
 * @title IdentityRegistryStorage
 * @notice Wallet -> (ONCHAINID, country) storage shared by every token's identity
 *         registry (T1.5, ADR 0016: one token per asset, shared identity storage).
 * @dev Writes come only from bound identity registries; binding is owner-only (ADR 0015).
 *      Immutable owner (ADR 0025). Capped at 300 bound registries as in T-REX.
 */
contract IdentityRegistryStorage is IIdentityRegistryStorage {
    uint256 public constant MAX_REGISTRIES = 300;

    /// @notice The governance multisig.
    address public immutable owner;

    struct Investor {
        IIdentity identity;
        uint16 country;
    }

    mapping(address => Investor) private _investors;
    address[] private _registries;
    mapping(address => bool) private _isRegistry;

    error NotOwner(address caller);
    error NotBoundRegistry(address caller);
    error ZeroAddress();
    error AlreadyStored(address user);
    error NotStored(address user);
    error RegistryAlreadyBound(address registry);
    error RegistryNotBound(address registry);
    error TooManyRegistries();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyRegistry() {
        if (!_isRegistry[msg.sender]) revert NotBoundRegistry(msg.sender);
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
    }

    /// @inheritdoc IIdentityRegistryStorage
    function addIdentityToStorage(address user, IIdentity identity_, uint16 country) external onlyRegistry {
        if (user == address(0) || address(identity_) == address(0)) revert ZeroAddress();
        if (address(_investors[user].identity) != address(0)) revert AlreadyStored(user);
        _investors[user] = Investor(identity_, country);
        emit IdentityStored(user, identity_);
    }

    /// @inheritdoc IIdentityRegistryStorage
    function removeIdentityFromStorage(address user) external onlyRegistry {
        IIdentity old = _investors[user].identity;
        if (address(old) == address(0)) revert NotStored(user);
        delete _investors[user];
        emit IdentityUnstored(user, old);
    }

    /// @inheritdoc IIdentityRegistryStorage
    function modifyStoredInvestorCountry(address user, uint16 country) external onlyRegistry {
        if (address(_investors[user].identity) == address(0)) revert NotStored(user);
        _investors[user].country = country;
        emit CountryModified(user, country);
    }

    /// @inheritdoc IIdentityRegistryStorage
    function modifyStoredIdentity(address user, IIdentity identity_) external onlyRegistry {
        if (address(identity_) == address(0)) revert ZeroAddress();
        IIdentity old = _investors[user].identity;
        if (address(old) == address(0)) revert NotStored(user);
        _investors[user].identity = identity_;
        emit IdentityModified(old, identity_);
    }

    /// @inheritdoc IIdentityRegistryStorage
    function bindIdentityRegistry(address registry) external onlyOwner {
        if (registry == address(0)) revert ZeroAddress();
        if (_isRegistry[registry]) revert RegistryAlreadyBound(registry);
        if (_registries.length >= MAX_REGISTRIES) revert TooManyRegistries();
        _isRegistry[registry] = true;
        _registries.push(registry);
        emit IdentityRegistryBound(registry);
    }

    /// @inheritdoc IIdentityRegistryStorage
    function unbindIdentityRegistry(address registry) external onlyOwner {
        if (!_isRegistry[registry]) revert RegistryNotBound(registry);
        uint256 n = _registries.length;
        for (uint256 i; i < n; ++i) {
            if (_registries[i] == registry) {
                _registries[i] = _registries[n - 1];
                _registries.pop();
                break;
            }
        }
        delete _isRegistry[registry];
        emit IdentityRegistryUnbound(registry);
    }

    /// @inheritdoc IIdentityRegistryStorage
    function linkedIdentityRegistries() external view returns (address[] memory) {
        return _registries;
    }

    /// @inheritdoc IIdentityRegistryStorage
    function storedIdentity(address user) external view returns (IIdentity) {
        return _investors[user].identity;
    }

    /// @inheritdoc IIdentityRegistryStorage
    function storedInvestorCountry(address user) external view returns (uint16) {
        return _investors[user].country;
    }
}
