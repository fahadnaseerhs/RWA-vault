// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../../identity/interfaces/IIdentity.sol";

/**
 * @title IIdentityRegistryStorage
 * @notice Shared storage of (wallet -> identity, country) mappings.
 * @dev Separated from IIdentityRegistry so that several tokens' registries can
 *      read one canonical investor set. Only bound Identity Registries may write.
 *      Part of the ERC-3643 permissioning system (Module 3). NatSpec for RWA-Vault.
 */
interface IIdentityRegistryStorage {
    /// @notice Emitted when an investor's identity is stored.
    event IdentityStored(address indexed investorAddress, IIdentity indexed identity);

    /// @notice Emitted when an investor's identity is removed.
    event IdentityUnstored(address indexed investorAddress, IIdentity indexed identity);

    /// @notice Emitted when an investor's identity contract is replaced.
    event IdentityModified(IIdentity indexed oldIdentity, IIdentity indexed newIdentity);

    /// @notice Emitted when an investor's stored country changes.
    event CountryModified(address indexed investorAddress, uint16 indexed country);

    /// @notice Emitted when an Identity Registry is granted write access to this storage.
    event IdentityRegistryBound(address indexed identityRegistry);

    /// @notice Emitted when an Identity Registry's write access is revoked.
    event IdentityRegistryUnbound(address indexed identityRegistry);

    /**
     * @notice Stores a new (wallet -> identity, country) record. Agent-only.
     * @param _userAddress the investor wallet.
     * @param _identity the investor's ONCHAINID identity contract.
     * @param _country ISO-3166 numeric country code of the investor.
     */
    function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country) external;

    /// @notice Removes an investor's stored record. Agent-only.
    function removeIdentityFromStorage(address _userAddress) external;

    /// @notice Updates an investor's stored country. Agent-only.
    function modifyStoredInvestorCountry(address _userAddress, uint16 _country) external;

    /// @notice Replaces an investor's stored identity contract. Agent-only.
    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external;

    /// @notice Grants an Identity Registry write access to this storage. Owner-only.
    function bindIdentityRegistry(address _identityRegistry) external;

    /// @notice Revokes an Identity Registry's write access. Owner-only.
    function unbindIdentityRegistry(address _identityRegistry) external;

    /// @notice Returns every Identity Registry bound to this storage.
    function linkedIdentityRegistries() external view returns (address[] memory);

    /// @notice Returns the identity contract stored for a wallet.
    function storedIdentity(address _userAddress) external view returns (IIdentity);

    /// @notice Returns the country code stored for a wallet.
    function storedInvestorCountry(address _userAddress) external view returns (uint16);
}
