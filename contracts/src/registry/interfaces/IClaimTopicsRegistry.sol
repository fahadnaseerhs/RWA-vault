// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IClaimTopicsRegistry
 * @notice The set of claim topics an investor must satisfy to hold the token.
 * @dev Part of the ERC-3643 permissioning system (Module 3, Registry). A wallet
 *      is "verified" only if its linked identity holds a valid claim for every
 *      required topic, issued by a trusted issuer. NatSpec authored for RWA-Vault.
 */
interface IClaimTopicsRegistry {
    /// @notice Emitted when a claim topic is added to the required set.
    event ClaimTopicAdded(uint256 indexed claimTopic);

    /// @notice Emitted when a claim topic is removed from the required set.
    event ClaimTopicRemoved(uint256 indexed claimTopic);

    /**
     * @notice Adds a claim topic to the required set. Owner-only.
     * @param _claimTopic the topic identifier to require.
     */
    function addClaimTopic(uint256 _claimTopic) external;

    /**
     * @notice Removes a claim topic from the required set. Owner-only.
     * @param _claimTopic the topic identifier to drop.
     */
    function removeClaimTopic(uint256 _claimTopic) external;

    /// @notice Returns the full set of required claim topics.
    function getClaimTopics() external view returns (uint256[] memory);
}
