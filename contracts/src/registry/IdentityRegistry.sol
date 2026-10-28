// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {IIdentityRegistryStorage} from "./interfaces/IIdentityRegistryStorage.sol";
import {ITrustedIssuersRegistry} from "./interfaces/ITrustedIssuersRegistry.sol";
import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";
import {IIdentity} from "../identity/interfaces/IIdentity.sol";
import {IClaimIssuer} from "../identity/interfaces/IClaimIssuer.sol";
import {OwnerAgentRoles} from "../access/OwnerAgentRoles.sol";

/**
 * @title IdentityRegistry
 * @notice "Who may hold": maps wallets to ONCHAINIDs and answers `isVerified` from the
 *         claims those identities hold (T1.5, ADR 0012, ADR 0013).
 * @dev A wallet is verified iff it has an identity and, for every required topic, that
 *      identity holds a claim from an issuer trusted for the topic which the issuer still
 *      confirms via `isClaimValid` (ECDSA, not revoked). Claim ids follow ERC-735 /
 *      ONCHAINID: `keccak256(abi.encode(issuer, topic))`. Calls into identities and issuers
 *      are wrapped so a broken or hostile identity makes the wallet unverified rather than
 *      reverting: every external call is try-wrapped (T1 spec §6 step 4). Agent = Tier 1 service key (registration); owner = multisig (wiring).
 */
contract IdentityRegistry is IIdentityRegistry, OwnerAgentRoles {
    IIdentityRegistryStorage private _storage;
    ITrustedIssuersRegistry private _issuers;
    IClaimTopicsRegistry private _topics;

    /// @notice `batchRegisterIdentity` arrays of unequal length.
    error LengthMismatch();

    constructor(
        address owner_,
        ITrustedIssuersRegistry issuers_,
        IClaimTopicsRegistry topics_,
        IIdentityRegistryStorage storage_
    ) OwnerAgentRoles(owner_) {
        if (address(issuers_) == address(0) || address(topics_) == address(0) || address(storage_) == address(0)) {
            revert ZeroAddress();
        }
        _issuers = issuers_;
        _topics = topics_;
        _storage = storage_;
        emit TrustedIssuersRegistrySet(address(issuers_));
        emit ClaimTopicsRegistrySet(address(topics_));
        emit IdentityStorageSet(address(storage_));
    }

    // ------------------------------------------------------------------
    // Agent
    // ------------------------------------------------------------------

    /// @inheritdoc IIdentityRegistry
    function registerIdentity(address user, IIdentity identity_, uint16 country) external onlyAgent {
        _register(user, identity_, country);
    }

    /// @inheritdoc IIdentityRegistry
    function batchRegisterIdentity(
        address[] calldata users,
        IIdentity[] calldata identities,
        uint16[] calldata countries
    ) external onlyAgent {
        if (users.length != identities.length || users.length != countries.length) {
            revert LengthMismatch();
        }
        for (uint256 i; i < users.length; ++i) {
            _register(users[i], identities[i], countries[i]);
        }
    }

    /// @inheritdoc IIdentityRegistry
    function deleteIdentity(address user) external onlyAgent {
        IIdentity old = _storage.storedIdentity(user);
        _storage.removeIdentityFromStorage(user);
        emit IdentityRemoved(user, old);
    }

    /// @inheritdoc IIdentityRegistry
    function updateCountry(address user, uint16 country) external onlyAgent {
        _storage.modifyStoredInvestorCountry(user, country);
        emit CountryUpdated(user, country);
    }

    /// @inheritdoc IIdentityRegistry
    function updateIdentity(address user, IIdentity identity_) external onlyAgent {
        IIdentity old = _storage.storedIdentity(user);
        _storage.modifyStoredIdentity(user, identity_);
        emit IdentityUpdated(old, identity_);
    }

    // ------------------------------------------------------------------
    // Owner
    // ------------------------------------------------------------------

    /// @inheritdoc IIdentityRegistry
    function setIdentityRegistryStorage(address storage_) external onlyOwner {
        if (storage_ == address(0)) revert ZeroAddress();
        _storage = IIdentityRegistryStorage(storage_);
        emit IdentityStorageSet(storage_);
    }

    /// @inheritdoc IIdentityRegistry
    function setClaimTopicsRegistry(address topics_) external onlyOwner {
        if (topics_ == address(0)) revert ZeroAddress();
        _topics = IClaimTopicsRegistry(topics_);
        emit ClaimTopicsRegistrySet(topics_);
    }

    /// @inheritdoc IIdentityRegistry
    function setTrustedIssuersRegistry(address issuers_) external onlyOwner {
        if (issuers_ == address(0)) revert ZeroAddress();
        _issuers = ITrustedIssuersRegistry(issuers_);
        emit TrustedIssuersRegistrySet(issuers_);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @inheritdoc IIdentityRegistry
    function contains(address user) external view returns (bool) {
        return address(_storage.storedIdentity(user)) != address(0);
    }

    /// @inheritdoc IIdentityRegistry
    function isVerified(address user) external view returns (bool) {
        IIdentity id;
        try _storage.storedIdentity(user) returns (IIdentity stored) {
            id = stored;
        } catch {
            return false;
        }
        if (address(id) == address(0)) return false;

        uint256[] memory topics;
        try _topics.getClaimTopics() returns (uint256[] memory t) {
            topics = t;
        } catch {
            return false;
        }
        for (uint256 t; t < topics.length; ++t) {
            if (!_hasValidClaim(id, topics[t])) return false;
        }
        return true;
    }

    /// @inheritdoc IIdentityRegistry
    function identity(address user) external view returns (IIdentity) {
        return _storage.storedIdentity(user);
    }

    /// @inheritdoc IIdentityRegistry
    function investorCountry(address user) external view returns (uint16) {
        return _storage.storedInvestorCountry(user);
    }

    /// @inheritdoc IIdentityRegistry
    function identityStorage() external view returns (IIdentityRegistryStorage) {
        return _storage;
    }

    /// @inheritdoc IIdentityRegistry
    function issuersRegistry() external view returns (ITrustedIssuersRegistry) {
        return _issuers;
    }

    /// @inheritdoc IIdentityRegistry
    function topicsRegistry() external view returns (IClaimTopicsRegistry) {
        return _topics;
    }

    // ------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------

    function _register(address user, IIdentity identity_, uint16 country) private {
        _storage.addIdentityToStorage(user, identity_, country);
        emit IdentityRegistered(user, identity_);
    }

    function _hasValidClaim(IIdentity id, uint256 topic) private view returns (bool) {
        IClaimIssuer[] memory trusted;
        try _issuers.getTrustedIssuersForClaimTopic(topic) returns (IClaimIssuer[] memory list) {
            trusted = list;
        } catch {
            return false;
        }
        for (uint256 i; i < trusted.length; ++i) {
            bytes32 claimId = keccak256(abi.encode(address(trusted[i]), topic));
            try id.getClaim(claimId) returns (
                uint256 foundTopic, uint256, address issuer, bytes memory sig, bytes memory data, string memory
            ) {
                if (foundTopic != topic || issuer != address(trusted[i])) continue;
                try trusted[i].isClaimValid(id, topic, sig, data) returns (bool ok) {
                    if (ok) return true;
                } catch {}
            } catch {}
        }
        return false;
    }
}
