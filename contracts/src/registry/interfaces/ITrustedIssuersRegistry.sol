// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "../../identity/interfaces/IClaimIssuer.sol";

/**
 * @title ITrustedIssuersRegistry
 * @notice The set of claim issuers the token trusts, and the topics each may attest.
 * @dev Part of the ERC-3643 permissioning system (Module 3, Registry). A claim only
 *      counts toward verification if its issuer is registered here for that topic.
 *      NatSpec authored for RWA-Vault.
 */
interface ITrustedIssuersRegistry {
    /// @notice Emitted when a trusted issuer is added, with the topics it may attest.
    event TrustedIssuerAdded(IClaimIssuer indexed trustedIssuer, uint256[] claimTopics);

    /// @notice Emitted when a trusted issuer is removed entirely.
    event TrustedIssuerRemoved(IClaimIssuer indexed trustedIssuer);

    /// @notice Emitted when the topic set of an existing trusted issuer changes.
    event ClaimTopicsUpdated(IClaimIssuer indexed trustedIssuer, uint256[] claimTopics);

    /**
     * @notice Registers a trusted issuer for a set of claim topics. Owner-only.
     * @param _trustedIssuer the issuer's claim-issuer contract.
     * @param _claimTopics the topics this issuer is trusted to attest (non-empty).
     */
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external;

    /// @notice Removes a trusted issuer and all of its topic authorisations. Owner-only.
    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external;

    /// @notice Replaces the topic set a trusted issuer may attest. Owner-only.
    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external;

    /// @notice Returns every registered trusted issuer.
    function getTrustedIssuers() external view returns (IClaimIssuer[] memory);

    /// @notice Returns the trusted issuers authorised for a specific claim topic.
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view returns (IClaimIssuer[] memory);

    /// @notice Returns true if the address is a registered trusted issuer.
    function isTrustedIssuer(address _issuer) external view returns (bool);

    /// @notice Returns the topics a given trusted issuer is authorised to attest.
    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer) external view returns (uint256[] memory);

    /// @notice Returns true if the issuer is trusted for the specific topic.
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view returns (bool);
}
