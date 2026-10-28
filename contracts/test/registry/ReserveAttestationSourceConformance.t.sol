// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";

/**
 * @title ReserveAttestationSourceConformanceTest
 * @notice Behaviour contract every {IReserveAttestationSource} implementation must pass:
 *         the MS1 envelope source (T4.4) and the Phase 2 Module 5 oracle alike.
 * @dev Interface-first acceptance spec, in the shape of `ERC3643Acceptance.t.sol`. It is
 *      `abstract` on purpose: Forge does not run abstract test contracts, so it compiles
 *      today with no implementation present. An implementation provides a concrete
 *      subclass that overrides {deploySource} and {_attest}, and the requirements C1-C9
 *      (Obsidian note "T0.7 - Reserve Attestation Source" §7) then run unchanged.
 *
 *      The suite never names `submitAttestation` (C9): {_attest} is the subclass's own way
 *      of getting data into its source. Where a source must refuse an input (a
 *      non-increasing `seq`, a future `valuationTs`), the suite asserts only that the
 *      refusal took no effect on {latest}, field by field. A conforming source may revert
 *      (MS1, per spec §4) or silently ignore the input (a possible M5 oracle); both pass.
 */
abstract contract ReserveAttestationSourceConformanceTest is Test {
    IReserveAttestationSource internal source;

    bytes32 internal constant GOLD_LOT_001 = keccak256("gold-lot-001");
    bytes32 internal constant GOLD_LOT_002 = keccak256("gold-lot-002");
    bytes32 internal constant UNKNOWN = keccak256("never-attested");

    /// @dev A 1 kg kilobar at 999.9 fineness, in fine grams x 10^18 (ADR 0020).
    uint256 internal constant KILOBAR_FINE = 999_900_000_000_000_000_000;
    uint64 internal constant T0 = 1_761_609_600;

    /// @dev Deploy the implementation under test and return it.
    function deploySource() internal virtual returns (IReserveAttestationSource);

    /**
     * @dev Offer one attestation to the source through whatever ingestion path the
     *      implementation has (MS1: `try submitAttestation(...)` from an allow-listed
     *      submitter; M5: its oracle update). Return true if the source accepted it and
     *      false if it refused. Reverting is tolerated and treated as a refusal.
     */
    function _attest(bytes32 assetId, uint256 reserve, uint64 seq, uint64 valuationTs)
        internal
        virtual
        returns (bool accepted);

    function setUp() public virtual {
        vm.warp(T0);
        source = deploySource();
    }

    /// @dev External wrapper so a reverting {_attest} reads as a refusal, never as a test failure.
    function attestExternal(bytes32 assetId, uint256 reserve, uint64 seq, uint64 valuationTs) external returns (bool) {
        require(msg.sender == address(this), "self only");
        return _attest(assetId, reserve, seq, valuationTs);
    }

    /// @dev Offer an attestation; true only if the source accepted it.
    function _offer(bytes32 assetId, uint256 reserve, uint64 seq, uint64 valuationTs) internal returns (bool) {
        (bool ok, bytes memory ret) =
            address(this).call(abi.encodeCall(this.attestExternal, (assetId, reserve, seq, valuationTs)));
        return ok && abi.decode(ret, (bool));
    }

    /// @dev Offer an attestation the source must accept.
    function _accept(bytes32 assetId, uint256 reserve, uint64 seq, uint64 valuationTs) internal {
        assertTrue(_offer(assetId, reserve, seq, valuationTs), "source refused a valid attestation");
    }

    function _assertSame(
        IReserveAttestationSource.ReserveAttestation memory a,
        IReserveAttestationSource.ReserveAttestation memory b
    ) internal pure {
        assertEq(a.assetId, b.assetId, "assetId changed");
        assertEq(a.reserve, b.reserve, "reserve changed");
        assertEq(a.seq, b.seq, "seq changed");
        assertEq(a.valuationTs, b.valuationTs, "valuationTs changed");
    }

    /// C1: `latest(k).assetId == k` for any attested `k`.
    function test_LatestEchoesKey() public {
        _accept(GOLD_LOT_001, KILOBAR_FINE, 1, T0);
        _accept(GOLD_LOT_002, KILOBAR_FINE, 2, T0);
        assertEq(source.latest(GOLD_LOT_001).assetId, GOLD_LOT_001);
        assertEq(source.latest(GOLD_LOT_002).assetId, GOLD_LOT_002);
    }

    /// C2: `latest(unknown)` is all-zero, including `assetId == bytes32(0)`, before and after other assets attest.
    function test_UnknownAssetReturnsZeroedStruct() public {
        IReserveAttestationSource.ReserveAttestation memory zero;
        _assertSame(source.latest(UNKNOWN), zero);
        _accept(GOLD_LOT_001, KILOBAR_FINE, 1, T0);
        _assertSame(source.latest(UNKNOWN), zero); // includes assetId == bytes32(0) (AC-T07-7)
        assertFalse(source.hasAttestation(UNKNOWN));
    }

    /// C3: `hasAttestation` is false before, true after, and never regresses (not even after a refused input).
    function test_HasAttestationIsMonotonic() public {
        assertFalse(source.hasAttestation(GOLD_LOT_001));
        _accept(GOLD_LOT_001, KILOBAR_FINE, 1, T0);
        assertTrue(source.hasAttestation(GOLD_LOT_001));
        _accept(GOLD_LOT_001, KILOBAR_FINE, 2, T0);
        assertTrue(source.hasAttestation(GOLD_LOT_001));
        _offer(GOLD_LOT_001, KILOBAR_FINE, 2, T0); // non-increasing: must not take effect
        assertTrue(source.hasAttestation(GOLD_LOT_001));
    }

    /// C4a: accepted attestations strictly increase `seq` per asset, and each one updates `reserve`.
    function test_SequenceStrictlyIncreasesPerAsset() public {
        _accept(GOLD_LOT_001, KILOBAR_FINE, 5, T0);
        _accept(GOLD_LOT_001, KILOBAR_FINE - 1e18, 6, T0);
        IReserveAttestationSource.ReserveAttestation memory a = source.latest(GOLD_LOT_001);
        assertEq(a.seq, 6);
        assertEq(a.reserve, KILOBAR_FINE - 1e18);

        // Per asset: another asset's sequence is independent of this one's.
        _accept(GOLD_LOT_002, KILOBAR_FINE, 1, T0);
        assertEq(source.latest(GOLD_LOT_002).seq, 1);
        assertEq(source.latest(GOLD_LOT_001).seq, 6);
    }

    /// C4b: a non-increasing `seq` does not take effect: `latest()` is unchanged, field by field.
    /// @dev Each probe differs from the baseline in BOTH `reserve` and `valuationTs`, so a
    ///      "heartbeat" source that accepts an equal seq and refreshes only the timestamp
    ///      is caught: it would give a stale reserve a fresh `valuationTs` (ADR 0021).
    function test_NonIncreasingSequenceDoesNotTakeEffect() public {
        _accept(GOLD_LOT_001, KILOBAR_FINE, 5, T0 - 100);
        IReserveAttestationSource.ReserveAttestation memory before = source.latest(GOLD_LOT_001);

        _offer(GOLD_LOT_001, KILOBAR_FINE - 1, 5, T0); // equal seq: new reserve AND fresher ts
        _assertSame(source.latest(GOLD_LOT_001), before);

        _offer(GOLD_LOT_001, KILOBAR_FINE - 1, 4, T0 - 50); // lower seq: same idea
        _assertSame(source.latest(GOLD_LOT_001), before);
    }

    /// C4c: `seq = 0` is not a legal first attestation (spec §4.1): zero is how the registry
    ///      says "never admitted", so an asset whose only record has seq 0 could never be admitted.
    function test_ZeroSequenceIsNotAFirstAttestation() public {
        IReserveAttestationSource.ReserveAttestation memory zero;
        _offer(GOLD_LOT_001, KILOBAR_FINE, 0, T0);
        assertFalse(source.hasAttestation(GOLD_LOT_001));
        _assertSame(source.latest(GOLD_LOT_001), zero);
    }

    /// C5: neither view ever reverts, for any key.
    function test_ViewsNeverRevert(bytes32 key) public view {
        source.latest(key);
        source.hasAttestation(key);
    }

    /// C6: `reserve` is returned exactly as attested; no conversion inside the source (§6 rules 1-2).
    /// @dev Establishes a byte-exact round-trip only: any rounding, scaling or gross
    ///      substitution inside the source fails it. It CANNOT establish that the unit is
    ///      fine grams (the fixture says so; the source cannot know), round-down (rule 3) or
    ///      fail-closed fineness (rule 4): conversion happens before {_attest}, so those
    ///      stay spec prose plus the T4.4 / M5 boundary code.
    function test_ReserveUnitIsFineGrams() public {
        _accept(GOLD_LOT_001, KILOBAR_FINE, 1, T0);
        assertEq(source.latest(GOLD_LOT_001).reserve, KILOBAR_FINE, "reserve must round-trip exactly");
    }

    /// C7: attesting one asset never changes another asset's record.
    function test_AssetsAreIsolated() public {
        _accept(GOLD_LOT_002, 500e18, 3, T0 - 60);
        IReserveAttestationSource.ReserveAttestation memory b = source.latest(GOLD_LOT_002);

        // Sequence numbers above B's, so a source that keyed both assets to one slot
        // would accept these and overwrite B, rather than refuse them on seq.
        _accept(GOLD_LOT_001, KILOBAR_FINE, 4, T0);
        _accept(GOLD_LOT_001, KILOBAR_FINE, 9, T0);
        _offer(GOLD_LOT_001, KILOBAR_FINE, 2, T0);

        _assertSame(source.latest(GOLD_LOT_002), b);
        assertTrue(source.hasAttestation(GOLD_LOT_002));
        assertEq(source.latest(GOLD_LOT_001).assetId, GOLD_LOT_001);
    }

    /// C8: a future `valuationTs` does not take effect: `latest()` is unchanged, field by field.
    function test_NoFutureValuation() public {
        _accept(GOLD_LOT_001, KILOBAR_FINE, 1, T0); // exactly now is acceptable
        IReserveAttestationSource.ReserveAttestation memory before = source.latest(GOLD_LOT_001);

        _offer(GOLD_LOT_001, KILOBAR_FINE, 2, T0 + 1);
        _assertSame(source.latest(GOLD_LOT_001), before);
    }

    /// C9: conformance requires exactly `latest` and `hasAttestation`; `submitAttestation` is not part of the interface.
    /// @dev Runs only inside a concrete subclass. The same pin runs today, concretely, as
    ///      `AssetRegistryInterfaceTest.test_ReserveSourceInterfaceIdIsPinned`.
    function test_InterfaceIsReadOnly() public pure {
        assertEq(
            type(IReserveAttestationSource).interfaceId,
            IReserveAttestationSource.latest.selector ^ IReserveAttestationSource.hasAttestation.selector
        );
    }
}
