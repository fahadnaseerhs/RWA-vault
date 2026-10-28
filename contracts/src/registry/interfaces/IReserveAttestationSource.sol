// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IReserveAttestationSource
 * @notice Read-only seam through which the AssetRegistry learns an asset's attested
 *         reserve, sequence and valuation time (ADR 0017).
 * @dev For MS1, admission clause 1 is verified off-chain (ADR 0027): the M2 verifier —
 *      or `pqctl` with M1's ML-DSA-65 verify until M2 exists — checks the custodian
 *      envelope, and an allow-listed Tier 1 submitter then records the decoded fields
 *      plus the envelope hash via the implementation's own `submitAttestation`. This
 *      contract verifies no signature. M9 anchors the hash, so anyone may fetch the
 *      original envelope and re-verify it offline against the custodian's registered
 *      key. The registry checks clauses 2-4 at `admit`.
 *
 *      `submitAttestation` is deliberately NOT part of this interface: in Phase 2 the
 *      Module 5 oracle implements {latest} directly and has no envelope to submit, so
 *      the registry never changes (ADR 0017). Conforming implementations subclass
 *      `test/registry/ReserveAttestationSourceConformance.t.sol`. Full specification:
 *      Obsidian note "T0.7 - Reserve Attestation Source". NatSpec authored for RWA-Vault.
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
     * @notice Clause 1 failed: the custodian's signature on an attestation is not valid
     *         for the registered custodian key.
     * @dev Under ADR 0027 no MS1 contract raises this: clause 1 is checked off-chain, and
     *      this error is the name the off-chain verifier's reporting path uses, so the
     *      operator sees the same sentence (T6 §3.4). It is reserved for a Phase 2
     *      implementation that verifies on-chain. Never raised by the registry.
     */
    error BadAttestationSig();

    /**
     * @notice Returns the latest accepted attestation for `assetId`. Anyone may call.
     * @dev Returns a zeroed struct when none exists; callers must check
     *      {hasAttestation} first (the registry reverts `NoAttestation` rather than
     *      read a zero reserve as valid). In the zeroed case `assetId` MUST be
     *      `bytes32(0)`, never the queried key, so a caller that skips {hasAttestation}
     *      but cross-checks `assetId` still fails closed (`AssetIdMismatch`).
     */
    function latest(bytes32 assetId) external view returns (ReserveAttestation memory);

    /// @notice Returns true if an attestation has ever been accepted for `assetId`. Anyone may call.
    function hasAttestation(bytes32 assetId) external view returns (bool);
}
