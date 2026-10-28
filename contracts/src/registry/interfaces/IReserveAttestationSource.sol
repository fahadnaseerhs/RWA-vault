// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IReserveAttestationSource
 * @notice Read-only seam through which the AssetRegistry learns an asset's attested
 *         reserve, sequence and valuation time (ADR 0017).
 * @dev For MS1 the implementation is fed by a signed ML-DSA-65 custodian envelope via
 *      its own `submitAttestation(bytes)`, which is deliberately NOT part of this
 *      interface: in Phase 2 the Module 5 oracle implements {latest} directly and has
 *      no envelope to submit, so the registry never changes. Signature verification
 *      (admission clause 1) therefore happens on the source at submit time; the
 *      registry checks clauses 2-4 at `admit`. Only the slice T0.6 needs to compile;
 *      T0.7's full research is still owed. NatSpec authored for RWA-Vault.
 */
interface IReserveAttestationSource {
    /**
     * @notice The latest accepted attestation for one asset.
     * @dev `assetId` repeats the lookup key on purpose and must stay the FIRST member
     *      (the struct is returned by value and decoded off-chain). The registry
     *      cross-checks it at `admit` and reverts `AssetIdMismatch`, so a source keyed
     *      wrongly (e.g. a later M5 implementation) cannot hand one asset's reserve to
     *      another with every clause passing (ADR 0019).
     * @param assetId the asset this attestation is about; must equal the key passed to {latest}.
     * @param reserve attested reserve. `reserve`, `intendedSupply` and `attestedSupply` are
     *        all in the token's own base units and must never be mixed with any other
     *        measure of the same asset. For gold that unit is fine grams x 10^18
     *        (ADR 0020); gross weight never appears.
     * @param seq attestation sequence; must strictly increase (admission clause 2).
     * @param valuationTs valuation time in Unix seconds (admission clause 4).
     */
    struct ReserveAttestation {
        bytes32 assetId;
        uint256 reserve;
        uint64 seq;
        uint64 valuationTs;
    }

    /**
     * @notice Clause 1 failed: the custodian's signature on a submitted attestation is
     *         not valid for the registered custodian key. Raised by the implementation's
     *         submit path, never by the registry.
     */
    error BadAttestationSig();

    /**
     * @notice Returns the latest accepted attestation for `assetId`. Anyone may call.
     * @dev Returns a zeroed struct when none exists; callers must check
     *      {hasAttestation} first (the registry reverts `NoAttestation` rather than
     *      read a zero reserve as valid).
     */
    function latest(bytes32 assetId) external view returns (ReserveAttestation memory);

    /// @notice Returns true if an attestation has ever been accepted for `assetId`. Anyone may call.
    function hasAttestation(bytes32 assetId) external view returns (bool);
}
