// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @title MockClaimIssuer
 * @notice Minimal test mock for an ONCHAINID `IClaimIssuer` contract.
 * @dev Implements only `isClaimValid` (called by `IdentityRegistry.isVerified`)
 *      and `revokeClaimBySignature` (for revocation tests). All other calls hit
 *      the fallback.
 *
 *      By default all claims are valid. Call `revokeClaimBySignature` to revoke
 *      a specific claim, or `mockSetAllInvalid` to make all claims fail.
 *
 *      NOT for production. Test-only.
 */
contract MockClaimIssuer {
    mapping(bytes32 => bool) private _revoked;
    bool private _allInvalid;

    /// @dev Test helper: mark all future isClaimValid calls as invalid.
    function mockSetAllInvalid(bool invalid) external {
        _allInvalid = invalid;
    }

    /// @dev Revokes a claim by its signature.
    function revokeClaimBySignature(bytes calldata _signature) external {
        _revoked[keccak256(_signature)] = true;
    }

    /// @dev Returns true if the claim signature has been revoked.
    function isClaimRevoked(bytes calldata _sig) external view returns (bool) {
        return _revoked[keccak256(_sig)];
    }

    /// @dev Validates a claim. Returns true unless the claim is revoked or all are marked invalid.
    function isClaimValid(
        address,
        /* _identity */
        uint256,
        /* claimTopic */
        bytes calldata sig,
        bytes calldata /* data */
    )
        external
        view
        returns (bool)
    {
        if (_allInvalid) return false;
        if (_revoked[keccak256(sig)]) return false;
        return true;
    }

    // ── Fallback for all other IClaimIssuer/IIdentity calls ──────────────────

    fallback() external payable {}
    receive() external payable {}
}
