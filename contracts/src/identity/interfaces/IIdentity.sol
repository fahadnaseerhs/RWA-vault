// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "./IERC734.sol";
import "./IERC735.sol";

/**
 * @title IIdentity — ONCHAINID
 * @notice An on-chain identity: a key holder (ERC-734) that also holds claims (ERC-735).
 * @dev This is the identity contract an investor's wallet is mapped to in the
 *      ERC-3643 Identity Registry. Verification of a wallet is verification of
 *      the claims held by its linked IIdentity. NatSpec authored for RWA-Vault.
 */
interface IIdentity is IERC734, IERC735 {
    /**
     * @notice Checks that a claim held by `_identity` for `claimTopic` is validly
     *         signed by this issuer and has not been revoked.
     * @param _identity the identity bearing the claim.
     * @param claimTopic the topic the claim must attest.
     * @param sig issuer signature over the claim.
     * @param data claim payload.
     * @return true if the claim is present, correctly signed and not revoked.
     */
    function isClaimValid(IIdentity _identity, uint256 claimTopic, bytes calldata sig, bytes calldata data)
        external
        view
        returns (bool);
}
