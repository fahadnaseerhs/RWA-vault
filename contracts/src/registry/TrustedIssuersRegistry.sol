// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {ITrustedIssuersRegistry} from "./interfaces/ITrustedIssuersRegistry.sol";
import {IClaimIssuer} from "../identity/interfaces/IClaimIssuer.sol";

/**
 * @title TrustedIssuersRegistry
 * @notice Which claim issuers are trusted, and for which topics (T1.4). MS1 has one
 *         ECDSA project KYC issuer bound to the `KYC` topic (Q03 = A, ADR 0013).
 * @dev Owner-only writes; immutable owner (ADR 0025). Caps follow the T-REX reference:
 *      50 issuers, 15 topics per issuer, so `isVerified` stays bounded in gas.
 */
contract TrustedIssuersRegistry is ITrustedIssuersRegistry {
    uint256 public constant MAX_ISSUERS = 50;
    uint256 public constant MAX_TOPICS_PER_ISSUER = 15;

    /// @notice The governance multisig.
    address public immutable owner;

    IClaimIssuer[] private _issuers;
    mapping(address => uint256[]) private _topicsOf;
    mapping(uint256 => IClaimIssuer[]) private _issuersFor;

    error NotOwner(address caller);
    error ZeroAddress();
    error IssuerAlreadyTrusted(address issuer);
    error IssuerNotTrusted(address issuer);
    error NoClaimTopics();
    error TooManyTopics();
    error TooManyIssuers();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function addTrustedIssuer(IClaimIssuer issuer, uint256[] calldata claimTopics) external onlyOwner {
        address a = address(issuer);
        if (a == address(0)) revert ZeroAddress();
        if (_topicsOf[a].length != 0) revert IssuerAlreadyTrusted(a);
        _checkTopics(claimTopics);
        if (_issuers.length >= MAX_ISSUERS) revert TooManyIssuers();

        _issuers.push(issuer);
        _topicsOf[a] = claimTopics;
        for (uint256 i; i < claimTopics.length; ++i) {
            _issuersFor[claimTopics[i]].push(issuer);
        }
        emit TrustedIssuerAdded(issuer, claimTopics);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function removeTrustedIssuer(IClaimIssuer issuer) external onlyOwner {
        address a = address(issuer);
        if (_topicsOf[a].length == 0) revert IssuerNotTrusted(a);
        _unindex(issuer);
        _removeFrom(_issuers, issuer);
        delete _topicsOf[a];
        emit TrustedIssuerRemoved(issuer);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function updateIssuerClaimTopics(IClaimIssuer issuer, uint256[] calldata claimTopics) external onlyOwner {
        address a = address(issuer);
        if (_topicsOf[a].length == 0) revert IssuerNotTrusted(a);
        _checkTopics(claimTopics);
        _unindex(issuer);
        _topicsOf[a] = claimTopics;
        for (uint256 i; i < claimTopics.length; ++i) {
            _issuersFor[claimTopics[i]].push(issuer);
        }
        emit ClaimTopicsUpdated(issuer, claimTopics);
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function getTrustedIssuers() external view returns (IClaimIssuer[] memory) {
        return _issuers;
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view returns (IClaimIssuer[] memory) {
        return _issuersFor[claimTopic];
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function isTrustedIssuer(address issuer) external view returns (bool) {
        return _topicsOf[issuer].length != 0;
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function getTrustedIssuerClaimTopics(IClaimIssuer issuer) external view returns (uint256[] memory) {
        address a = address(issuer);
        if (_topicsOf[a].length == 0) revert IssuerNotTrusted(a);
        return _topicsOf[a];
    }

    /// @inheritdoc ITrustedIssuersRegistry
    function hasClaimTopic(address issuer, uint256 claimTopic) external view returns (bool) {
        uint256[] storage t = _topicsOf[issuer];
        for (uint256 i; i < t.length; ++i) {
            if (t[i] == claimTopic) return true;
        }
        return false;
    }

    function _checkTopics(uint256[] calldata claimTopics) private pure {
        if (claimTopics.length == 0) revert NoClaimTopics();
        if (claimTopics.length > MAX_TOPICS_PER_ISSUER) revert TooManyTopics();
    }

    function _unindex(IClaimIssuer issuer) private {
        uint256[] storage t = _topicsOf[address(issuer)];
        for (uint256 i; i < t.length; ++i) {
            _removeFrom(_issuersFor[t[i]], issuer);
        }
    }

    function _removeFrom(IClaimIssuer[] storage list, IClaimIssuer issuer) private {
        uint256 n = list.length;
        for (uint256 i; i < n; ++i) {
            if (list[i] == issuer) {
                list[i] = list[n - 1];
                list.pop();
                return;
            }
        }
    }
}
