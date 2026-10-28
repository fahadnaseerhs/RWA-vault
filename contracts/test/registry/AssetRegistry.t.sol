// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AssetRegistry} from "../../src/registry/AssetRegistry.sol";
import {IAssetRegistry, MAX_VALUATION_WINDOW} from "../../src/registry/interfaces/IAssetRegistry.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";
import {MockAttestationSource} from "./mocks/MockAttestationSource.sol";
import {MockSupplyToken} from "./mocks/MockSupplyToken.sol";

/**
 * @title AssetRegistryTest
 * @notice T4.1 state machine, T4.2 clauses 2-4 and T4.6 transition tests for {AssetRegistry}.
 * @dev Windows are always set short (Q13 test rule): nothing here assumes 24 hours.
 */
contract AssetRegistryTest is Test {
    AssetRegistry internal reg;
    MockAttestationSource internal src;
    MockSupplyToken internal token;

    address internal owner = makeAddr("owner");
    address internal agent = makeAddr("agent");
    address internal stranger = makeAddr("stranger");

    string internal constant REF = "gold-lot-001";
    bytes32 internal ID = keccak256(bytes(REF));
    bytes32 internal constant META = keccak256("metadata");
    uint64 internal constant WINDOW = 1 hours;
    uint256 internal constant KILOBAR = 999.9e18; // 1 kg at 999.9 fine, in fine-gram units (ADR 0020)

    function setUp() public {
        vm.warp(1_800_000_000);
        reg = new AssetRegistry(owner);
        src = new MockAttestationSource();
        token = new MockSupplyToken();

        vm.startPrank(owner);
        reg.addAgent(agent);
        reg.setAttestationSource(address(src));
        reg.setValuationWindow(WINDOW);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- helpers

    function _attest(uint256 reserve, uint64 seq, uint64 valuationTs) internal {
        src.set(ID, IReserveAttestationSource.ReserveAttestation(ID, reserve, seq, valuationTs));
    }

    function _register() internal {
        vm.prank(agent);
        reg.register(ID, META, REF);
    }

    function _live() internal {
        _register();
        _attest(KILOBAR, 1, uint64(block.timestamp));
        vm.prank(agent);
        reg.admit(ID, KILOBAR);
    }

    // ---------------------------------------------------------------- construction

    function test_ConstructorSetsOwner() public view {
        assertEq(reg.owner(), owner);
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, address(0)));
        new AssetRegistry(address(0));
    }

    function test_UnknownAssetIsUnregistered() public view {
        assertEq(uint8(reg.stateOf(ID)), uint8(IAssetRegistry.AssetState.UNREGISTERED));
        assertFalse(reg.isLive(ID));
    }

    // ---------------------------------------------------------------- register

    function test_RegisterMovesToPending() public {
        vm.expectEmit(true, false, false, true, address(reg));
        emit IAssetRegistry.AssetRegistered(ID, REF, META);
        _register();

        assertEq(uint8(reg.stateOf(ID)), uint8(IAssetRegistry.AssetState.PENDING));
        assertEq(reg.metadataHashOf(ID), META);
        assertEq(reg.assetRefOf(ID), REF);
        assertFalse(reg.isLive(ID));
    }

    function test_RegisterRejectsEmptyId() public {
        vm.prank(agent);
        vm.expectRevert(IAssetRegistry.EmptyAssetId.selector);
        reg.register(bytes32(0), META, REF);
    }

    function test_RegisterTwiceReverts() public {
        _register();
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetAlreadyRegistered.selector, ID));
        reg.register(ID, META, REF);
    }

    function test_RegisterOnlyAgent() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotAuthorisedAgent.selector, stranger));
        reg.register(ID, META, REF);
    }

    function test_RegisterRejectsSlugMismatch() public {
        bytes32 wrong = keccak256("gold-lot-999");
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetRefMismatch.selector, wrong, ID));
        reg.register(wrong, META, REF);
    }

    function test_RegisterRejectsEmptyRef() public {
        vm.prank(agent);
        vm.expectRevert(IAssetRegistry.EmptyAssetId.selector);
        reg.register(ID, META, "");
    }

    // ---------------------------------------------------------------- admit: happy paths

    function test_AdmitPendingToLive() public {
        _register();
        _attest(KILOBAR, 1, uint64(block.timestamp));

        vm.expectEmit(true, false, false, true, address(reg));
        emit IAssetRegistry.AssetAdmitted(ID, KILOBAR, 1, uint64(block.timestamp));
        vm.prank(agent);
        reg.admit(ID, KILOBAR);

        assertTrue(reg.isLive(ID));
        assertEq(reg.reserveOf(ID), KILOBAR);
        assertEq(reg.lastSequenceOf(ID), 1);
    }

    function test_AdmitAtExactWindowBoundaryPasses() public {
        _register();
        _attest(KILOBAR, 1, uint64(block.timestamp) - WINDOW);
        vm.prank(agent);
        reg.admit(ID, KILOBAR);
        assertTrue(reg.isLive(ID));
    }

    function test_ReattestKeepsLive() public {
        _live();
        vm.warp(block.timestamp + 10 minutes);
        _attest(KILOBAR + 1e18, 2, uint64(block.timestamp));
        vm.prank(agent);
        reg.admit(ID, 0);

        assertTrue(reg.isLive(ID));
        assertEq(reg.reserveOf(ID), KILOBAR + 1e18);
        assertEq(reg.lastSequenceOf(ID), 2);
    }

    /// ADR 0019 §3 / Q14=B: below current supply is accepted, recorded and signalled; no auto-freeze.
    function test_ReattestBelowSupplyAcceptedWithUnderReserve() public {
        _live();
        vm.prank(owner);
        reg.setTokenFor(ID, address(token));
        token.setTotalSupply(KILOBAR);

        _attest(900e18, 2, uint64(block.timestamp));
        vm.expectEmit(true, false, false, true, address(reg));
        emit IAssetRegistry.UnderReserve(ID, 900e18, KILOBAR);
        vm.prank(agent);
        reg.admit(ID, 0);

        assertEq(reg.reserveOf(ID), 900e18);
        assertTrue(reg.isLive(ID));
    }

    function test_ReattestAtSupplyDoesNotSignalUnderReserve() public {
        _live();
        vm.prank(owner);
        reg.setTokenFor(ID, address(token));
        token.setTotalSupply(KILOBAR);

        _attest(KILOBAR, 2, uint64(block.timestamp));
        vm.recordLogs();
        vm.prank(agent);
        reg.admit(ID, 0);
        assertEq(vm.getRecordedLogs().length, 1); // AssetAdmitted only
    }

    /// Coder reading 2: a LIVE asset with no token bound is re-attested against a supply of 0.
    function test_ReattestWithNoTokenBoundTreatsSupplyAsZero() public {
        _live();
        _attest(1, 2, uint64(block.timestamp));
        vm.recordLogs();
        vm.prank(agent);
        reg.admit(ID, 0);
        assertEq(vm.getRecordedLogs().length, 1); // AssetAdmitted only, no UnderReserve
        assertEq(reg.reserveOf(ID), 1);
    }

    // ---------------------------------------------------------------- admit: rejections leave PENDING

    function _expectPendingUntouched() internal view {
        assertEq(uint8(reg.stateOf(ID)), uint8(IAssetRegistry.AssetState.PENDING));
        assertEq(reg.reserveOf(ID), 0);
        assertEq(reg.lastSequenceOf(ID), 0);
    }

    function test_AdmitUnregisteredReverts() public {
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotRegistered.selector, ID));
        reg.admit(ID, 1);
    }

    function test_AdmitOnlyAgent() public {
        _register();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotAuthorisedAgent.selector, stranger));
        reg.admit(ID, 1);
    }

    function test_AdmitWithoutAttestationReverts() public {
        _register();
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NoAttestation.selector, ID));
        reg.admit(ID, 1);
        _expectPendingUntouched();
    }

    function test_AdmitWithoutSourceReverts() public {
        AssetRegistry bare = new AssetRegistry(owner);
        vm.prank(owner);
        bare.addAgent(agent);
        vm.startPrank(agent);
        bare.register(ID, META, REF);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NoAttestation.selector, ID));
        bare.admit(ID, 1);
        vm.stopPrank();
    }

    function test_AdmitAssetIdMismatchReverts() public {
        _register();
        bytes32 other = keccak256("gold-lot-002");
        src.set(ID, IReserveAttestationSource.ReserveAttestation(other, KILOBAR, 1, uint64(block.timestamp)));
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetIdMismatch.selector, ID, other));
        reg.admit(ID, KILOBAR);
        _expectPendingUntouched();
    }

    function test_Clause2_ZeroSequenceRejectedOnFirstAdmission() public {
        _register();
        _attest(KILOBAR, 0, uint64(block.timestamp));
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.StaleSequence.selector, uint64(0), uint64(0)));
        reg.admit(ID, KILOBAR);
        _expectPendingUntouched();
    }

    function test_Clause2_ReplayRejected() public {
        _live();
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.StaleSequence.selector, uint64(1), uint64(1)));
        reg.admit(ID, 0);
    }

    function test_Clause3_ReserveBelowIntendedSupply() public {
        _register();
        _attest(KILOBAR - 1, 1, uint64(block.timestamp));
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.ReserveTooLow.selector, KILOBAR - 1, KILOBAR));
        reg.admit(ID, KILOBAR);
        _expectPendingUntouched();
    }

    function test_Clause4_StaleByOneSecond() public {
        _register();
        uint64 ts = uint64(block.timestamp) - WINDOW - 1;
        _attest(KILOBAR, 1, ts);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, ts, WINDOW));
        reg.admit(ID, KILOBAR);
        _expectPendingUntouched();
    }

    function test_Clause4_FutureTimestampIsNamedNotPanic() public {
        _register();
        uint64 ts = uint64(block.timestamp) + 1;
        _attest(KILOBAR, 1, ts);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.ValuationInFuture.selector, ts, uint64(block.timestamp)));
        reg.admit(ID, KILOBAR);
        _expectPendingUntouched();
    }

    function test_Clause4_ZeroWindowFailsClosed() public {
        AssetRegistry bare = new AssetRegistry(owner);
        vm.startPrank(owner);
        bare.addAgent(agent);
        bare.setAttestationSource(address(src));
        vm.stopPrank();

        _attest(KILOBAR, 1, uint64(block.timestamp));
        vm.startPrank(agent);
        bare.register(ID, META, REF);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, uint64(block.timestamp), uint64(0))
        );
        bare.admit(ID, KILOBAR);
        vm.stopPrank();
    }

    function test_Clause4_PerAssetOverrideWins() public {
        vm.prank(owner);
        reg.setValuationWindowFor(ID, 10 minutes);
        assertEq(reg.valuationWindowOf(ID), 10 minutes);
        assertEq(reg.valuationWindowOf(keccak256("other")), WINDOW);

        _register();
        uint64 ts = uint64(block.timestamp) - 11 minutes;
        _attest(KILOBAR, 1, ts);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, ts, uint64(10 minutes)));
        reg.admit(ID, KILOBAR);
    }

    /// A LIVE asset whose reserve has gone stale cannot be re-attested with the same stale figure.
    function test_ReattestStaleRejectedAndLiveUnchanged() public {
        _live();
        vm.warp(block.timestamp + WINDOW + 1);
        uint64 ts = uint64(block.timestamp) - WINDOW - 1;
        _attest(KILOBAR, 2, ts);
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, ts, WINDOW));
        reg.admit(ID, 0);
        assertEq(reg.lastSequenceOf(ID), 1);
        assertTrue(reg.isLive(ID));
    }

    function test_ValuationTsOfRecordsAdmitted() public {
        assertEq(reg.valuationTsOf(ID), 0);
        _register();
        uint64 ts = uint64(block.timestamp) - 5 minutes;
        _attest(KILOBAR, 1, ts);
        vm.prank(agent);
        reg.admit(ID, KILOBAR);
        assertEq(reg.valuationTsOf(ID), ts);

        vm.warp(block.timestamp + 1 minutes);
        _attest(KILOBAR, 2, uint64(block.timestamp));
        vm.prank(agent);
        reg.admit(ID, 0);
        assertEq(reg.valuationTsOf(ID), uint64(block.timestamp));
    }

    /// Reading 6: the replay guard belongs to the asset, so a new source must continue the sequence.
    function test_SourceSwapKeepsLastSeq() public {
        _register();
        _attest(KILOBAR, 5, uint64(block.timestamp));
        vm.prank(agent);
        reg.admit(ID, KILOBAR);

        MockAttestationSource fresh = new MockAttestationSource();
        vm.prank(owner);
        reg.setAttestationSource(address(fresh));
        assertEq(reg.lastSequenceOf(ID), 5);

        fresh.set(ID, IReserveAttestationSource.ReserveAttestation(ID, KILOBAR, 1, uint64(block.timestamp)));
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.StaleSequence.selector, uint64(1), uint64(5)));
        reg.admit(ID, 0);

        fresh.set(ID, IReserveAttestationSource.ReserveAttestation(ID, KILOBAR, 6, uint64(block.timestamp)));
        vm.prank(agent);
        reg.admit(ID, 0);
        assertEq(reg.lastSequenceOf(ID), 6);
    }

    // ---------------------------------------------------------------- freeze / unfreeze

    function test_FreezeAndUnfreeze() public {
        _live();
        vm.expectEmit(true, false, false, true, address(reg));
        emit IAssetRegistry.AssetFrozen(ID, "incident");
        vm.prank(agent);
        reg.freeze(ID, "incident");
        assertEq(uint8(reg.stateOf(ID)), uint8(IAssetRegistry.AssetState.FROZEN));
        assertFalse(reg.isLive(ID));

        vm.expectEmit(true, false, false, false, address(reg));
        emit IAssetRegistry.AssetUnfrozen(ID);
        vm.prank(owner);
        reg.unfreeze(ID);
        assertTrue(reg.isLive(ID));
    }

    function test_FreezeOnlyAgent_UnfreezeOnlyOwner() public {
        _live();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotAuthorisedAgent.selector, owner));
        reg.freeze(ID, "x");

        vm.prank(agent);
        reg.freeze(ID, "x");
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, agent));
        reg.unfreeze(ID);
    }

    function test_FreezeRequiresLive() public {
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotRegistered.selector, ID));
        reg.freeze(ID, "x");

        _register();
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.AssetNotLive.selector, ID, IAssetRegistry.AssetState.PENDING)
        );
        reg.freeze(ID, "x");
    }

    function test_FreezeTwiceReverts() public {
        _live();
        vm.prank(agent);
        reg.freeze(ID, "x");
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.AssetNotLive.selector, ID, IAssetRegistry.AssetState.FROZEN)
        );
        reg.freeze(ID, "x");
    }

    function test_UnfreezeRequiresFrozen() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotRegistered.selector, ID));
        reg.unfreeze(ID);

        _live();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFrozen.selector, ID));
        reg.unfreeze(ID);
    }

    function test_AdmitOnFrozenReverts() public {
        _live();
        vm.prank(agent);
        reg.freeze(ID, "x");
        _attest(KILOBAR, 2, uint64(block.timestamp));
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.AssetNotLive.selector, ID, IAssetRegistry.AssetState.FROZEN)
        );
        reg.admit(ID, 0);
    }

    // ---------------------------------------------------------------- token binding

    function test_SetTokenForBindsBothWays() public {
        _register();
        vm.expectEmit(true, false, false, true, address(reg));
        emit IAssetRegistry.AssetTokenBound(ID, address(token));
        vm.prank(owner);
        reg.setTokenFor(ID, address(token));

        assertEq(reg.tokenOf(ID), address(token));
        assertEq(reg.assetOfToken(address(token)), ID);
        token.setTotalSupply(42);
        assertEq(reg.attestedSupplyOf(ID), 42);
    }

    function test_AttestedSupplyRevertsWhenUnbound() public {
        _register();
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.TokenNotBound.selector, ID));
        reg.attestedSupplyOf(ID);
    }

    function test_UnboundTokenMapsToZeroAsset() public view {
        assertEq(reg.assetOfToken(address(token)), bytes32(0));
        assertFalse(reg.isLive(reg.assetOfToken(address(token))));
    }

    function test_SetTokenForRejections() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotRegistered.selector, ID));
        reg.setTokenFor(ID, address(token));
        vm.stopPrank();

        _register();
        bytes32 id2 = keccak256("gold-lot-002");
        vm.prank(agent);
        reg.register(id2, META, "gold-lot-002");

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.InvalidTokenBinding.selector, address(0)));
        reg.setTokenFor(ID, address(0));

        reg.setTokenFor(ID, address(token));
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetAlreadyHasToken.selector, ID, address(token)));
        reg.setTokenFor(ID, address(0xBEEF));

        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.TokenAlreadyBound.selector, address(token), ID));
        reg.setTokenFor(id2, address(token));
        vm.stopPrank();
    }

    function test_SetTokenForOnlyOwner() public {
        _register();
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, agent));
        reg.setTokenFor(ID, address(token));
    }

    // ---------------------------------------------------------------- owner setters

    function test_ValuationWindowBounds() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.InvalidValuationWindow.selector, uint64(0)));
        reg.setValuationWindow(0);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.InvalidValuationWindow.selector, MAX_VALUATION_WINDOW + 1)
        );
        reg.setValuationWindow(MAX_VALUATION_WINDOW + 1);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.InvalidValuationWindow.selector, uint64(0)));
        reg.setValuationWindowFor(ID, 0);
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.InvalidValuationWindow.selector, MAX_VALUATION_WINDOW + 1)
        );
        reg.setValuationWindowFor(ID, MAX_VALUATION_WINDOW + 1);

        vm.expectEmit(false, false, false, true, address(reg));
        emit IAssetRegistry.ValuationWindowSet(MAX_VALUATION_WINDOW);
        reg.setValuationWindow(MAX_VALUATION_WINDOW);
        vm.expectEmit(true, false, false, true, address(reg));
        emit IAssetRegistry.ValuationWindowSetFor(ID, 1);
        reg.setValuationWindowFor(ID, 1);
        vm.stopPrank();
    }

    function test_SettersOnlyOwner() public {
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, stranger));
        reg.setValuationWindow(1);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, stranger));
        reg.setValuationWindowFor(ID, 1);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, stranger));
        reg.setAttestationSource(address(src));
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, stranger));
        reg.addAgent(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotOwner.selector, stranger));
        reg.removeAgent(agent);
        vm.stopPrank();
    }

    function test_SetAttestationSourceRejectsUnusable() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.InvalidAttestationSource.selector, address(0)));
        reg.setAttestationSource(address(0));
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.InvalidAttestationSource.selector, stranger));
        reg.setAttestationSource(stranger); // an EOA has no code
        vm.stopPrank();
        assertEq(reg.attestationSource(), address(src));
    }

    function test_AgentManagement() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.InvalidAgent.selector, address(0)));
        reg.addAgent(address(0));
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.InvalidAgent.selector, address(0)));
        reg.removeAgent(address(0));
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AgentUnchanged.selector, agent));
        reg.addAgent(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AgentUnchanged.selector, stranger));
        reg.removeAgent(stranger);

        vm.expectEmit(true, false, false, false, address(reg));
        emit IAssetRegistry.AgentRemoved(agent);
        reg.removeAgent(agent);
        vm.stopPrank();
        assertFalse(reg.isAgent(agent));

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.NotAuthorisedAgent.selector, agent));
        reg.register(ID, META, REF);
    }

    // ---------------------------------------------------------------- fuzz

    /// Clause 4 boundary across arbitrary windows and ages: passes iff age <= window.
    function testFuzz_Clause4Boundary(uint64 window, uint64 age) public {
        window = uint64(bound(window, 1, MAX_VALUATION_WINDOW));
        age = uint64(bound(age, 0, uint64(block.timestamp)));
        vm.prank(owner);
        reg.setValuationWindow(window);
        _register();
        uint64 ts = uint64(block.timestamp) - age;
        _attest(KILOBAR, 1, ts);

        if (age > window) {
            vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, ts, window));
        }
        vm.prank(agent);
        reg.admit(ID, KILOBAR);
        assertEq(reg.isLive(ID), age <= window);
    }

    /// Clause 2: only a strictly greater sequence is ever accepted.
    function testFuzz_Clause2Monotonic(uint64 first, uint64 second) public {
        first = uint64(bound(first, 1, type(uint64).max));
        _register();
        _attest(KILOBAR, first, uint64(block.timestamp));
        vm.prank(agent);
        reg.admit(ID, KILOBAR);

        _attest(KILOBAR, second, uint64(block.timestamp));
        if (second <= first) {
            vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.StaleSequence.selector, second, first));
        }
        vm.prank(agent);
        reg.admit(ID, 0);
        assertEq(reg.lastSequenceOf(ID), second > first ? second : first);
    }
}
