// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./ITrustedIssuersRegistry.sol";
import "./IClaimTopicsRegistry.sol";
import "./IIdentityRegistryStorage.sol";
import "../../identity/interfaces/IIdentity.sol";

/**
 * @title IIdentityRegistry
 * @notice The on-chain gatekeeper: maps investor wallets to identities and answers
 *         "is this wallet allowed to hold the token?".
 * @dev The heart of ERC-3643 permissioning (Module 3, Registry). `isVerified`
 *      returns true only when the wallet's linked identity holds a valid, non-revoked
 *      claim — issued by a trusted issuer — for every topic in the claim-topics set.
 *      The token calls `isVerified` on every mint and transfer. NatSpec for RWA-Vault.
 */
interface IIdentityRegistry {
    /// @notice Emitted when the claim-topics registry is (re)set.
    event ClaimTopicsRegistrySet(address indexed claimTopicsRegistry);

    /// @notice Emitted when the backing identity storage is (re)set.
    event IdentityStorageSet(address indexed identityStorage);

    /// @notice Emitted when the trusted-issuers registry is (re)set.
    event TrustedIssuersRegistrySet(address indexed trustedIssuersRegistry);

    /// @notice Emitted when a wallet is registered with an identity.
    event IdentityRegistered(address indexed investorAddress, IIdentity indexed identity);

    /// @notice Emitted when a wallet's identity is removed.
    event IdentityRemoved(address indexed investorAddress, IIdentity indexed identity);

    /// @notice Emitted when a wallet's identity contract is replaced.
    event IdentityUpdated(IIdentity indexed oldIdentity, IIdentity indexed newIdentity);

    /// @notice Emitted when a wallet's country code is updated.
    event CountryUpdated(address indexed investorAddress, uint16 indexed country);

    /**
     * @notice Registers a wallet with its identity and country. Agent-only.
     * @param _userAddress the investor wallet.
     * @param _identity the investor's ONCHAINID identity contract.
     * @param _country ISO-3166 numeric country code.
     */
    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) external;

    /// @notice Removes a wallet from the registry. Agent-only.
    function deleteIdentity(address _userAddress) external;

    /// @notice Sets the backing identity storage contract. Owner-only.
    function setIdentityRegistryStorage(address _identityRegistryStorage) external;

    /// @notice Sets the claim-topics registry. Owner-only.
    function setClaimTopicsRegistry(address _claimTopicsRegistry) external;

    /// @notice Sets the trusted-issuers registry. Owner-only.
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external;

    /// @notice Updates a registered wallet's country code. Agent-only.
    function updateCountry(address _userAddress, uint16 _country) external;

    /// @notice Replaces a registered wallet's identity contract. Agent-only.
    function updateIdentity(address _userAddress, IIdentity _identity) external;

    /**
     * @notice Batch form of {registerIdentity}. Arrays must be equal length.
     * @dev May exceed the block gas limit for large batches — use with care.
     */
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    ) external;

    /// @notice Returns true if the wallet has a registered identity.
    function contains(address _userAddress) external view returns (bool);

    /**
     * @notice The verification check consumed by the token on mint/transfer.
     * @return true if the wallet's identity satisfies every required claim topic
     *         via a trusted, non-revoked issuer claim.
     */
    function isVerified(address _userAddress) external view returns (bool);

    /// @notice Returns the identity contract linked to a wallet.
    function identity(address _userAddress) external view returns (IIdentity);

    /// @notice Returns the country code registered for a wallet.
    function investorCountry(address _userAddress) external view returns (uint16);

    /// @notice Returns the backing identity storage contract.
    function identityStorage() external view returns (IIdentityRegistryStorage);

    /// @notice Returns the trusted-issuers registry.
    function issuersRegistry() external view returns (ITrustedIssuersRegistry);

    /// @notice Returns the claim-topics registry.
    function topicsRegistry() external view returns (IClaimTopicsRegistry);
}
