// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IIdentity.sol";

/**
 * @title IClaimIssuer — ONCHAINID
 * @notice An identity authorised to issue (and revoke) claims about other identities.
 * @dev Trusted issuers are registered per claim topic in the ITrustedIssuersRegistry.
 *      The Identity Registry trusts a claim only if its issuer is a registered
 *      IClaimIssuer for that topic and the claim is not revoked. NatSpec authored
 *      for RWA-Vault (Module 3, Registry).
 */
interface IClaimIssuer is IIdentity {
    /// @notice Emitted when a claim signature is revoked by this issuer.
    event ClaimRevoked(bytes indexed signature);

    /**
     * @notice Revokes a claim by its signature. Any claim carrying `_signature`
     *         is treated as invalid from that point on.
     * @param _signature the issuer signature to revoke.
     */
    function revokeClaimBySignature(bytes calldata _signature) external;

    /// @notice Returns true if the given claim signature has been revoked.
    function isClaimRevoked(bytes calldata _sig) external view returns (bool);

    /**
     * @notice Verifies that a claim held by `_identity` for `claimTopic` was signed
     *         by this issuer and has not been revoked.
     */
    function isClaimValid(IIdentity _identity, uint256 claimTopic, bytes calldata sig, bytes calldata data)
        external
        view
        returns (bool);

    /// @notice Recovers the signer address of a claim from its signature and data hash.
    function getRecoveredAddress(bytes calldata sig, bytes32 dataHash) external pure returns (address);
}
