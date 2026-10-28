// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IReserveAttestationSource} from "./interfaces/IReserveAttestationSource.sol";

/**
 * @title CustodianAttestationSource
 * @notice The MS1 reserve attestation source (T4.3, ADR 0017, ADR 0027): a Tier 1
 *         submitter records a custodian attestation and the hash of its ML-DSA-65 envelope.
 * @dev Clause 1 is verified OFF-chain (M2 verifier or `pqctl`); the submitter refuses to
 *      submit on failure, so on-chain clause 1 trusts the submitter (ADR 0027 disclosure).
 *      There is deliberately no signature check and no "verified" flag here, and no
 *      reserve, freshness or supply judgement: clauses 2-4 belong to `AssetRegistry.admit`.
 *      The sequence guard only stops a trusted-key typo overwriting a newer pending
 *      attestation. `envelopeHash` is opaque (its digest is M2 T3.8's call); M9 anchors it
 *      from {AttestationSubmitted}. Immutable owner (ADR 0025). This contract does not
 *      know the registry: the seam stays one-way (ADR 0017).
 */
contract CustodianAttestationSource is IReserveAttestationSource {
    /// @notice The governance multisig (ADR 0015). Manages submitters.
    address public immutable owner;

    mapping(bytes32 => ReserveAttestation) private _latest;
    mapping(bytes32 => bytes32) private _envelopeHash;
    mapping(address => bool) private _submitters;

    event SubmitterAdded(address indexed account);
    event SubmitterRemoved(address indexed account);
    event AttestationSubmitted(
        bytes32 indexed assetId,
        uint64 seq,
        uint256 reserve,
        uint64 valuationTs,
        bytes32 envelopeHash,
        address indexed submitter
    );

    error NotOwner(address caller);
    error NotAuthorisedSubmitter(address caller);
    error InvalidSubmitter(address account);
    error SubmitterUnchanged(address account);
    error EmptyAssetId();
    error MissingEnvelopeHash();
    error SequenceNotIncreasing(uint64 submitted, uint64 latest);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert NotOwner(address(0));
        owner = owner_;
    }

    /// @notice Grants the submitter role. Owner-only; not idempotent.
    function addSubmitter(address account) external onlyOwner {
        if (account == address(0)) revert InvalidSubmitter(account);
        if (_submitters[account]) revert SubmitterUnchanged(account);
        _submitters[account] = true;
        emit SubmitterAdded(account);
    }

    /// @notice Revokes the submitter role. Owner-only; not idempotent.
    function removeSubmitter(address account) external onlyOwner {
        if (account == address(0)) revert InvalidSubmitter(account);
        if (!_submitters[account]) revert SubmitterUnchanged(account);
        _submitters[account] = false;
        emit SubmitterRemoved(account);
    }

    /// @notice Returns true if `account` may submit attestations.
    function isSubmitter(address account) external view returns (bool) {
        return _submitters[account];
    }

    /**
     * @notice Records an attestation whose envelope the caller has verified off-chain.
     * @dev `reserve == 0` is accepted: a custodian saying "zero" is information.
     * @param att the attestation decoded from the envelope.
     * @param envelopeHash the 32-byte digest of the signed envelope (non-zero).
     */
    function submitAttestation(ReserveAttestation calldata att, bytes32 envelopeHash) external {
        if (!_submitters[msg.sender]) revert NotAuthorisedSubmitter(msg.sender);
        if (att.assetId == bytes32(0)) revert EmptyAssetId();
        if (envelopeHash == bytes32(0)) revert MissingEnvelopeHash();
        uint64 latestSeq = _latest[att.assetId].seq;
        if (att.seq <= latestSeq) revert SequenceNotIncreasing(att.seq, latestSeq);

        _latest[att.assetId] = att;
        _envelopeHash[att.assetId] = envelopeHash;
        emit AttestationSubmitted(att.assetId, att.seq, att.reserve, att.valuationTs, envelopeHash, msg.sender);
    }

    /// @notice Returns the envelope hash of the latest attestation for `assetId`; zero if none.
    function envelopeHashOf(bytes32 assetId) external view returns (bytes32) {
        return _envelopeHash[assetId];
    }

    /// @inheritdoc IReserveAttestationSource
    function latest(bytes32 assetId) external view returns (ReserveAttestation memory) {
        return _latest[assetId];
    }

    /// @inheritdoc IReserveAttestationSource
    function hasAttestation(bytes32 assetId) external view returns (bool) {
        return _envelopeHash[assetId] != bytes32(0);
    }
}
