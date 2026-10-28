// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistry
 * @notice The claim topics a wallet's identity must hold to be verified (T1.3). MS1
 *         requires one topic, `KYC_TOPIC` (Q02 = A, `ClaimTopics.sol`), seeded by the deploy script.
 * @dev Owner-only writes (ADR 0015); immutable owner (ADR 0025). Capped at 15 topics as
 *      in the T-REX reference, so `isVerified` stays bounded in gas.
 */
contract ClaimTopicsRegistry is IClaimTopicsRegistry {
    /// @notice Maximum number of required topics.
    uint256 public constant MAX_TOPICS = 15;

    /// @notice The governance multisig.
    address public immutable owner;

    uint256[] private _topics;

    error NotOwner(address caller);
    error ClaimTopicAlreadyExists(uint256 claimTopic);
    error ClaimTopicNotFound(uint256 claimTopic);
    error TooManyClaimTopics();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert NotOwner(address(0));
        owner = owner_;
    }

    /// @inheritdoc IClaimTopicsRegistry
    function addClaimTopic(uint256 claimTopic) external onlyOwner {
        uint256 n = _topics.length;
        if (n >= MAX_TOPICS) revert TooManyClaimTopics();
        for (uint256 i; i < n; ++i) {
            if (_topics[i] == claimTopic) revert ClaimTopicAlreadyExists(claimTopic);
        }
        _topics.push(claimTopic);
        emit ClaimTopicAdded(claimTopic);
    }

    /// @inheritdoc IClaimTopicsRegistry
    function removeClaimTopic(uint256 claimTopic) external onlyOwner {
        uint256 n = _topics.length;
        for (uint256 i; i < n; ++i) {
            if (_topics[i] == claimTopic) {
                _topics[i] = _topics[n - 1];
                _topics.pop();
                emit ClaimTopicRemoved(claimTopic);
                return;
            }
        }
        revert ClaimTopicNotFound(claimTopic);
    }

    /// @inheritdoc IClaimTopicsRegistry
    function getClaimTopics() external view returns (uint256[] memory) {
        return _topics;
    }
}
