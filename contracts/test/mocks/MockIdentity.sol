// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @title MockIdentity
 * @notice Minimal test mock for an ONCHAINID `IIdentity` contract.
 * @dev Implements only the functions actually called by `IdentityRegistry.isVerified`:
 *      `getClaimIdsByTopic` and `getClaim`. All other IERC734/IERC735 calls hit the
 *      fallback and return empty. This is sufficient because Solidity encodes interface
 *      calls by selector, not by type — the mock responds to the right selectors.
 *
 *      NOT for production. Test-only.
 */
contract MockIdentity {
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
    }

    mapping(bytes32 => Claim) private _claims;
    mapping(uint256 => bytes32[]) private _claimsByTopic;

    /// @dev Test helper: add a claim directly.
    function mockAddClaim(
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory sig,
        bytes memory data,
        string memory uri
    ) external returns (bytes32) {
        bytes32 claimId = keccak256(abi.encode(issuer, topic));
        _claims[claimId] = Claim(topic, scheme, issuer, sig, data, uri);
        _claimsByTopic[topic].push(claimId);
        return claimId;
    }

    /// @dev Test helper: remove all claims for a topic (for testing claim removal scenarios).
    function mockClearClaimsForTopic(uint256 topic) external {
        bytes32[] storage ids = _claimsByTopic[topic];
        for (uint256 i = 0; i < ids.length; i++) {
            delete _claims[ids[i]];
        }
        delete _claimsByTopic[topic];
    }

    // ── IERC735 functions called by isVerified ───────────────────────────────

    function getClaimIdsByTopic(uint256 _topic) external view returns (bytes32[] memory) {
        return _claimsByTopic[_topic];
    }

    function getClaim(bytes32 _claimId)
        external
        view
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        )
    {
        Claim storage c = _claims[_claimId];
        return (c.topic, c.scheme, c.issuer, c.signature, c.data, c.uri);
    }

    // ── Fallback for all other IERC734/IERC735 calls ─────────────────────────

    fallback() external payable {}
    receive() external payable {}
}
