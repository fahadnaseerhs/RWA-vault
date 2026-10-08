// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IERC735 — Claim Holder
 * @notice Claim-management interface used by ONCHAINID identity contracts.
 * @dev Reproduces the ERC-735 standard function and event signatures. Claims are
 *      signed attestations (e.g. KYC/AML, accreditation) issued by trusted issuers
 *      and consumed by the ERC-3643 Identity Registry's `isVerified` check.
 *      NatSpec authored for RWA-Vault (Module 3, Registry).
 */
interface IERC735 {
    /// @notice Emitted when a claim is requested on the identity.
    event ClaimRequested(
        uint256 indexed claimRequestId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    /// @notice Emitted when a claim is added to the identity.
    event ClaimAdded(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    /// @notice Emitted when a claim is removed from the identity.
    event ClaimRemoved(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    /// @notice Emitted when an existing claim is changed.
    event ClaimChanged(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    /**
     * @notice Adds or updates a claim. The claim id is keccak256(abi.encode(issuer, topic)).
     * @param _topic claim topic (e.g. a KYC topic required by the token).
     * @param _scheme signature scheme identifier.
     * @param _issuer address of the claim issuer (a trusted issuer's contract).
     * @param _signature issuer signature over the claim data.
     * @param _data claim payload.
     * @param _uri off-chain location of supporting data.
     */
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri
    ) external returns (bytes32 claimRequestId);

    /// @notice Removes a claim from the identity by its id.
    function removeClaim(bytes32 _claimId) external returns (bool success);

    /// @notice Returns the stored fields of a claim.
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
        );

    /// @notice Returns every claim id registered under a topic.
    function getClaimIdsByTopic(uint256 _topic) external view returns (bytes32[] memory claimIds);
}
