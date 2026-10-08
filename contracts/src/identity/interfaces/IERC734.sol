// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IERC734 — Key Holder
 * @notice Key-management interface used by ONCHAINID identity contracts.
 * @dev Reproduces the ERC-734 standard function and event signatures so the
 *      ERC-3643 identity layer (Module 3, Registry) can resolve against it.
 *      NatSpec authored for RWA-Vault; signatures follow the ERC-734 proposal.
 *      Purpose values used by ERC-3643: 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM.
 */
interface IERC734 {
    /// @notice Emitted when an execution request is approved or rejected.
    event Approved(uint256 indexed executionId, bool approved);

    /// @notice Emitted when an approved execution is carried out.
    event Executed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);

    /// @notice Emitted when an execution is requested (and pending approval).
    event ExecutionRequested(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);

    /// @notice Emitted when an approved execution reverts.
    event ExecutionFailed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);

    /// @notice Emitted when a key is added to the identity.
    event KeyAdded(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);

    /// @notice Emitted when a key is removed from the identity.
    event KeyRemoved(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);

    /**
     * @notice Adds a key, or a new purpose to an existing key.
     * @param _key keccak256 hash of the key's address/public key.
     * @param _purpose purpose category (e.g. 1 MANAGEMENT, 3 CLAIM).
     * @param _keyType cryptographic scheme of the key (e.g. 1 ECDSA).
     */
    function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) external returns (bool success);

    /// @notice Approves or rejects a pending execution request.
    function approve(uint256 _id, bool _approve) external returns (bool success);

    /// @notice Removes a purpose from a key (and the key itself if it was the last purpose).
    function removeKey(bytes32 _key, uint256 _purpose) external returns (bool success);

    /// @notice Requests execution of a call from the identity; may auto-run if the caller holds the required purpose.
    function execute(address _to, uint256 _value, bytes calldata _data) external payable returns (uint256 executionId);

    /// @notice Returns the purposes, key type and key hash for a stored key.
    function getKey(bytes32 _key) external view returns (uint256[] memory purposes, uint256 keyType, bytes32 key);

    /// @notice Returns every purpose attached to a key.
    function getKeyPurposes(bytes32 _key) external view returns (uint256[] memory _purposes);

    /// @notice Returns every key registered for a given purpose.
    function getKeysByPurpose(uint256 _purpose) external view returns (bytes32[] memory keys);

    /// @notice Returns true if the key carries the given purpose.
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view returns (bool exists);
}
