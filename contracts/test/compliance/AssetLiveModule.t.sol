// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ModularCompliance} from "../../src/compliance/ModularCompliance.sol";
import {AssetLiveModule} from "../../src/compliance/modules/AssetLiveModule.sol";
import {AssetRegistry} from "../../src/registry/AssetRegistry.sol";
import {IAssetRegistry} from "../../src/registry/interfaces/IAssetRegistry.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";
import {MockAttestationSource} from "../registry/mocks/MockAttestationSource.sol";
import {MockSupplyToken} from "../registry/mocks/MockSupplyToken.sol";

/**
 * @title AssetLiveModuleTest
 * @notice T2.2: the module vetoes mints (returns false, never reverts) unless the asset is
 *         LIVE and `supply + value <= reserve`; transfers and burns always pass (ADR 0019 §6).
 * @dev Runs against the real {AssetRegistry} (T4.1) rather than the mock.
 */
contract AssetLiveModuleTest is Test {
    AssetRegistry internal reg;
    MockAttestationSource internal src;
    MockSupplyToken internal token;
    ModularCompliance internal mc;
    AssetLiveModule internal mod;

    address internal owner = makeAddr("owner");
    address internal agent = makeAddr("agent");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    bytes32 internal ID = keccak256("gold-lot-001");
    uint256 internal constant RESERVE = 1000e18;

    function setUp() public {
        vm.warp(1_800_000_000);
        reg = new AssetRegistry(owner);
        src = new MockAttestationSource();
        token = new MockSupplyToken();
        mc = new ModularCompliance(owner);
        mod = new AssetLiveModule(IAssetRegistry(address(reg)));

        vm.startPrank(owner);
        reg.addAgent(agent);
        reg.setAttestationSource(address(src));
        reg.setValuationWindow(1 hours);
        mc.bindToken(address(token));
        mc.addModule(address(mod));
        vm.stopPrank();

        vm.prank(agent);
        reg.register(ID, bytes32(0), "gold-lot-001");
    }

    function _admit(uint256 reserve, uint64 seq) internal {
        src.set(ID, IReserveAttestationSource.ReserveAttestation(ID, reserve, seq, uint64(block.timestamp)));
        vm.prank(agent);
        reg.admit(ID, 0);
    }

    function _bindAndLive() internal {
        vm.prank(owner);
        reg.setTokenFor(ID, address(token));
        _admit(RESERVE, 1);
    }

    function test_Metadata() public view {
        assertEq(mod.name(), "AssetLiveModule");
        assertTrue(mod.isPlugAndPlay());
        assertTrue(mod.canComplianceBind(address(mc)));
        assertTrue(mod.isComplianceBound(address(mc)));
        assertEq(address(mod.registry()), address(reg));
    }

    function test_ConstructorRejectsZeroRegistry() public {
        vm.expectRevert(AssetLiveModule.ZeroRegistry.selector);
        new AssetLiveModule(IAssetRegistry(address(0)));
    }

    // ---------------------------------------------------------------- mint veto

    function test_MintRefusedWhenTokenNotBoundToAsset() public {
        _admit(RESERVE, 1); // LIVE, but registry has no token for it
        assertFalse(mc.canTransfer(address(0), alice, 1));
    }

    function test_MintRefusedWhenPending() public {
        vm.prank(owner);
        reg.setTokenFor(ID, address(token));
        assertFalse(mc.canTransfer(address(0), alice, 1));
    }

    function test_MintAllowedWhenLiveWithinReserve() public {
        _bindAndLive();
        assertTrue(mc.canTransfer(address(0), alice, RESERVE));
    }

    function test_MintCapBoundaryExact() public {
        _bindAndLive();
        token.setTotalSupply(RESERVE - 10);
        assertTrue(mc.canTransfer(address(0), alice, 10));
        assertFalse(mc.canTransfer(address(0), alice, 11));
    }

    function test_MintRefusedWhenFrozen() public {
        _bindAndLive();
        vm.prank(agent);
        reg.freeze(ID, "incident");
        assertFalse(mc.canTransfer(address(0), alice, 1));
    }

    function test_MintRefusedWhenUnderReserve() public {
        _bindAndLive();
        token.setTotalSupply(RESERVE);
        _admit(900e18, 2); // accepted with UnderReserve, still LIVE
        assertTrue(reg.isLive(ID));
        assertFalse(mc.canTransfer(address(0), alice, 1));
    }

    function test_MintHugeValueDoesNotOverflow() public {
        _bindAndLive();
        token.setTotalSupply(1);
        assertFalse(mc.canTransfer(address(0), alice, type(uint256).max));
    }

    // ---------------------------------------------------------------- freshness (ADR 0021)

    function test_MintBlockedWhenReserveStale() public {
        _bindAndLive(); // tau = 1h
        vm.warp(block.timestamp + 2 days);
        assertTrue(reg.isLive(ID));
        assertFalse(mc.canTransfer(address(0), alice, 1));
    }

    function test_MintAllowedAtExactWindow() public {
        _bindAndLive();
        vm.warp(block.timestamp + 1 hours);
        assertTrue(mc.canTransfer(address(0), alice, 1));
        vm.warp(block.timestamp + 1);
        assertFalse(mc.canTransfer(address(0), alice, 1));
    }

    function test_TransferAllowedWhenReserveStale() public {
        _bindAndLive();
        vm.warp(block.timestamp + 2 days);
        assertTrue(mc.canTransfer(alice, bob, 1));
        assertTrue(mc.canTransfer(alice, address(0), 1));
    }

    function test_MintBlockedAfterUnfreezeUntilReattested() public {
        _bindAndLive();
        vm.prank(agent);
        reg.freeze(ID, "incident");
        vm.warp(block.timestamp + 2 hours);
        vm.prank(owner);
        reg.unfreeze(ID);
        assertTrue(reg.isLive(ID));
        assertFalse(mc.canTransfer(address(0), alice, 1));

        _admit(RESERVE, 2);
        assertTrue(mc.canTransfer(address(0), alice, 1));
    }

    function test_ShorterPerAssetWindowAppliesToMint() public {
        _bindAndLive();
        vm.prank(owner);
        reg.setValuationWindowFor(ID, 10 minutes);
        vm.warp(block.timestamp + 11 minutes);
        assertFalse(mc.canTransfer(address(0), alice, 1));
    }

    function test_OwnerCanUnbindSquatterThenTokenBinds() public {
        ModularCompliance fresh = new ModularCompliance(owner);
        address squatter = makeAddr("squatter");
        vm.prank(squatter);
        fresh.bindToken(squatter);
        vm.prank(address(token));
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.TokenBindingRefused.selector, address(token)));
        fresh.bindToken(address(token));

        vm.prank(owner);
        fresh.unbindToken(squatter);
        vm.prank(address(token));
        fresh.bindToken(address(token));
        assertEq(fresh.getTokenBound(), address(token));
    }

    // ---------------------------------------------------------------- transfers pass

    function test_TransfersAndBurnsPassWhenFrozen() public {
        _bindAndLive();
        vm.prank(agent);
        reg.freeze(ID, "incident");
        assertTrue(mc.canTransfer(alice, bob, 5));
        assertTrue(mc.canTransfer(alice, address(0), 5));
    }

    function test_TransfersPassWhenUnderReserveOrUnregistered() public {
        assertTrue(mc.canTransfer(alice, bob, type(uint256).max)); // asset PENDING, no token bound
        _bindAndLive();
        token.setTotalSupply(RESERVE);
        _admit(1, 2);
        assertTrue(mc.canTransfer(alice, bob, RESERVE));
    }

    function test_DirectModuleCheckWithUnboundComplianceFailsClosed() public {
        ModularCompliance empty = new ModularCompliance(owner);
        assertFalse(mod.moduleCheck(address(0), alice, 1, address(empty)));
    }

    // ---------------------------------------------------------------- binding

    function test_BindOnlyByComplianceItself() public {
        vm.expectRevert(abi.encodeWithSelector(AssetLiveModule.OnlyCompliance.selector, address(this)));
        mod.bindCompliance(alice);
        vm.prank(address(mc));
        vm.expectRevert(abi.encodeWithSelector(AssetLiveModule.ComplianceAlreadyBound.selector, address(mc)));
        mod.bindCompliance(address(mc));
    }

    function test_UnbindViaRemoveModule() public {
        vm.prank(owner);
        mc.removeModule(address(mod));
        assertFalse(mod.isComplianceBound(address(mc)));
        vm.prank(address(mc));
        vm.expectRevert(abi.encodeWithSelector(AssetLiveModule.ComplianceNotBound.selector, address(mc)));
        mod.unbindCompliance(address(mc));
    }

    function test_HooksRequireBoundCompliance() public {
        vm.prank(address(token));
        mc.created(alice, 1); // bound compliance -> module accepts
        vm.expectRevert(abi.encodeWithSelector(AssetLiveModule.ComplianceNotBound.selector, address(this)));
        mod.moduleMintAction(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(AssetLiveModule.ComplianceNotBound.selector, address(this)));
        mod.moduleTransferAction(alice, bob, 1);
        vm.expectRevert(abi.encodeWithSelector(AssetLiveModule.ComplianceNotBound.selector, address(this)));
        mod.moduleBurnAction(alice, 1);
    }

    // ---------------------------------------------------------------- fuzz

    function testFuzz_MintCap(uint256 supply, uint256 value) public {
        _bindAndLive();
        supply = bound(supply, 0, RESERVE * 2);
        token.setTotalSupply(supply);
        bool expected = supply <= RESERVE && value <= RESERVE - supply;
        assertEq(mc.canTransfer(address(0), alice, value), expected);
        assertTrue(mc.canTransfer(alice, bob, value));
    }
}
