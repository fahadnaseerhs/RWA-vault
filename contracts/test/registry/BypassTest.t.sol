// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {M3System} from "../helpers/M3System.sol";
import {Token} from "../../src/tokens/Token.sol";
import {OwnerAgentRoles} from "../../src/access/OwnerAgentRoles.sol";
import {ModularCompliance} from "../../src/compliance/ModularCompliance.sol";

/**
 * @title BypassTest
 * @notice T6.3 / AC-17: every call goes straight to the token, with no script, service or
 *         console in front of it, and the chain alone must refuse. Covers the verification
 *         gate (ReceiverNotVerified) and the liveness gate in compliance (AssetLiveModule),
 *         with the AC-17 correction from the T3 spec §10: a transfer of a non-LIVE asset
 *         succeeds (ADR 0019 §6); the liveness gate is on mints.
 */
contract BypassTest is M3System {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal unverified = makeAddr("never-kyc");
    uint256 internal constant RESERVE = 1_000e18;

    function setUp() public {
        vm.warp(1_800_000_000);
        _deployM3();
        _onboardInvestor(alice, 586);
        _onboardInvestor(bob, 586);
    }

    function _liveWithAliceHolding(uint256 amount) internal {
        _onboardAsset(RESERVE);
        vm.prank(irAgent);
        tok.mint(alice, amount);
    }

    // ---------------------------------------------------------------- AC-17

    function test_DirectTransferToUnverifiedReverts() public {
        _liveWithAliceHolding(10e18);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Token.ReceiverNotVerified.selector, unverified));
        tok.transfer(unverified, 1e18);
        assertEq(tok.balanceOf(unverified), 0);
    }

    function test_DirectMintToUnverifiedReverts() public {
        _onboardAsset(RESERVE);
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(Token.ReceiverNotVerified.selector, unverified));
        tok.mint(unverified, 1e18);
        assertEq(tok.totalSupply(), 0);
    }

    /// @dev Replaces AC-17's `test_DirectTransferWhenAssetNotLiveReverts` (T3 spec §10).
    function test_DirectMintWhenAssetNotLiveReverts() public {
        // PENDING: registered and bound, never admitted.
        vm.prank(irAgent);
        assetRegistry.register(ASSET_ID, keccak256("fixture-metadata"), ASSET_REF);
        vm.prank(govOwner);
        assetRegistry.setTokenFor(ASSET_ID, address(tok));

        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(Token.TransferNotCompliant.selector, address(0), alice, 1e18));
        tok.mint(alice, 1e18);

        // FROZEN: admitted, then frozen by the agent.
        _attestAndAdmit(RESERVE);
        vm.startPrank(irAgent);
        assetRegistry.freeze(ASSET_ID, "custody check");
        vm.expectRevert(abi.encodeWithSelector(Token.TransferNotCompliant.selector, address(0), alice, 1e18));
        tok.mint(alice, 1e18);
        vm.stopPrank();
        assertEq(tok.totalSupply(), 0);
    }

    /// @dev The positive twin (ADR 0019 §6): holders can still move title while the asset is frozen.
    function test_DirectTransferWhenAssetFrozenSucceeds() public {
        _liveWithAliceHolding(10e18);
        vm.prank(irAgent);
        assetRegistry.freeze(ASSET_ID, "custody check");

        vm.prank(alice);
        assertTrue(tok.transfer(bob, 4e18));
        assertEq(tok.balanceOf(bob), 4e18);
    }

    // ---------------------------------------------------------------- the other direct routes

    function test_DirectMintBeyondReserveReverts() public {
        _liveWithAliceHolding(RESERVE - 1);
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(Token.TransferNotCompliant.selector, address(0), alice, 2));
        tok.mint(alice, 2);
    }

    function test_DirectMintWhenReserveStaleReverts() public {
        _onboardAsset(RESERVE);
        vm.warp(block.timestamp + WINDOW + 1);
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(Token.TransferNotCompliant.selector, address(0), alice, 1e18));
        tok.mint(alice, 1e18);
    }

    function test_DirectMintByNonAgentReverts() public {
        _onboardAsset(RESERVE);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAuthorisedAgent.selector, alice));
        tok.mint(alice, 1e18);
    }

    function test_DirectComplianceHookCallReverts() public {
        // Nobody but the bound token may move compliance state.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotBoundToken.selector, alice));
        mc.created(alice, 1e18);
    }
}
