// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {M3System} from "../helpers/M3System.sol";
import {Token} from "../../src/tokens/Token.sol";
import {IERC3643} from "../../src/tokens/interfaces/IERC3643.sol";
import {IIdentity} from "../../src/identity/interfaces/IIdentity.sol";
import {OwnerAgentRoles} from "../../src/access/OwnerAgentRoles.sol";
import {ModularCompliance} from "../../src/compliance/ModularCompliance.sol";
import {IModularCompliance} from "../../src/compliance/interfaces/IModularCompliance.sol";

/**
 * @title TokenTest
 * @notice T3.1-T3.4 unit tests per the T3 build spec §8, on the real wired suite.
 */
contract TokenTest is M3System {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol"); // never verified
    address internal stranger = makeAddr("stranger");
    uint256 internal constant RESERVE = 10_000e18;

    function setUp() public {
        vm.warp(1_800_000_000);
        _deployM3();
        _onboardInvestor(alice, 586);
        _onboardInvestor(bob, 586);
    }

    function _live() internal {
        _onboardAsset(RESERVE);
    }

    function _mint(address to, uint256 amt) internal {
        vm.prank(irAgent);
        tok.mint(to, amt);
    }

    function _notCompliant(address from, address to, uint256 amt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(Token.TransferNotCompliant.selector, from, to, amt);
    }

    // ---------------------------------------------------------------- construction

    function test_ConstructionState() public {
        assertEq(tok.decimals(), 18);
        assertEq(tok.name(), "QORA Gold Lot 001");
        assertEq(tok.symbol(), "qXAU-001");
        assertEq(tok.version(), "rwa-vault-3643-1.0.0");
        assertEq(address(tok.identityRegistry()), address(ir));
        assertEq(address(tok.compliance()), address(mc));
        assertEq(mc.getTokenBound(), address(tok));
        assertEq(tok.owner(), govOwner);

        Token fresh = new Token(govOwner, address(ir), address(new ModularCompliance(govOwner)), "n", "s", address(0));
        assertTrue(fresh.paused()); // deployed paused (T-REX)
    }

    function test_ConstructorRejectsZeros() public {
        ModularCompliance c = new ModularCompliance(govOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, address(0)));
        new Token(address(0), address(ir), address(c), "n", "s", address(0));
        vm.expectRevert(OwnerAgentRoles.ZeroAddress.selector);
        new Token(govOwner, address(0), address(c), "n", "s", address(0));
        vm.expectRevert(OwnerAgentRoles.ZeroAddress.selector);
        new Token(govOwner, address(ir), address(0), "n", "s", address(0));
    }

    // ---------------------------------------------------------------- mint path

    function test_MintToVerifiedWithinReserve() public {
        _live();
        _mint(alice, RESERVE);
        assertEq(tok.balanceOf(alice), RESERVE);
        assertEq(assetRegistry.attestedSupplyOf(ASSET_ID), RESERVE);
    }

    function test_MintToUnverifiedReverts() public {
        _live();
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(Token.ReceiverNotVerified.selector, carol));
        tok.mint(carol, 1);
    }

    function test_MintWhenAssetPendingReverts() public {
        vm.prank(irAgent);
        assetRegistry.register(ASSET_ID, bytes32(0), ASSET_REF);
        vm.prank(govOwner);
        assetRegistry.setTokenFor(ASSET_ID, address(tok));
        vm.prank(irAgent);
        vm.expectRevert(_notCompliant(address(0), alice, 1));
        tok.mint(alice, 1);
    }

    function test_MintWithNoAssetBoundReverts() public {
        vm.prank(irAgent);
        vm.expectRevert(_notCompliant(address(0), alice, 1));
        tok.mint(alice, 1);
    }

    function test_MintWhenAssetFrozenReverts() public {
        _live();
        vm.prank(irAgent);
        assetRegistry.freeze(ASSET_ID, "incident");
        vm.prank(irAgent);
        vm.expectRevert(_notCompliant(address(0), alice, 1));
        tok.mint(alice, 1);
    }

    function test_MintWhenReserveStaleReverts() public {
        _live();
        vm.warp(block.timestamp + WINDOW + 1);
        vm.prank(irAgent);
        vm.expectRevert(_notCompliant(address(0), alice, 1));
        tok.mint(alice, 1);
    }

    function test_MintBeyondReserveReverts() public {
        _live();
        vm.prank(irAgent);
        vm.expectRevert(_notCompliant(address(0), alice, RESERVE + 1));
        tok.mint(alice, RESERVE + 1);
    }

    /// T0.6 §18.2: fails if `_mint` ran before `canTransfer` (the post-mint supply would be compared).
    function test_MintOrderComplianceBeforeMint() public {
        _live();
        _mint(alice, RESERVE - 5);
        uint256 over = RESERVE - tok.totalSupply() + 1;
        vm.prank(irAgent);
        vm.expectRevert(_notCompliant(address(0), alice, over));
        tok.mint(alice, over);
        _mint(alice, over - 1); // exactly to the reserve
        assertEq(tok.totalSupply(), RESERVE);
    }

    function test_MintNotBlockedByPauseOrFrozenReceiver() public {
        _live();
        vm.startPrank(irAgent);
        tok.pause();
        tok.setAddressFrozen(alice, true);
        tok.mint(alice, 1);
        vm.stopPrank();
        assertEq(tok.balanceOf(alice), 1);
    }

    // ---------------------------------------------------------------- transfer path, each refusal in isolation

    function test_TransferWhenPausedReverts() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        tok.pause();
        vm.prank(alice);
        vm.expectRevert(Token.TokenPaused.selector);
        tok.transfer(bob, 1);
    }

    function test_TransferFromFrozenWalletReverts() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        tok.setAddressFrozen(alice, true);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Token.WalletFrozen.selector, alice));
        tok.transfer(bob, 1);
    }

    function test_TransferToFrozenWalletReverts() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        tok.setAddressFrozen(bob, true);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Token.WalletFrozen.selector, bob));
        tok.transfer(bob, 1);
    }

    function test_TransferAboveUnfrozenBalanceReverts() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        tok.freezePartialTokens(alice, 7);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Token.InsufficientUnfrozenBalance.selector, alice, 3, 4));
        tok.transfer(bob, 4);
        vm.prank(alice);
        tok.transfer(bob, 3);
    }

    function test_TransferToUnverifiedReverts() public {
        _live();
        _mint(alice, 10);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Token.ReceiverNotVerified.selector, carol));
        tok.transfer(carol, 1);
    }

    function test_TransferNotCompliantReverts() public {
        _live();
        _mint(alice, 10);
        // A module that refuses everything, added through the owner.
        RefuseAll refuse = new RefuseAll();
        vm.prank(govOwner);
        mc.addModule(address(refuse));
        vm.prank(alice);
        vm.expectRevert(_notCompliant(alice, bob, 1));
        tok.transfer(bob, 1);
    }

    function test_TransferFromUsesSameChecks() public {
        _live();
        _mint(alice, 10);
        vm.prank(alice);
        tok.approve(bob, 5);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Token.ReceiverNotVerified.selector, carol));
        tok.transferFrom(alice, carol, 1);
        vm.prank(bob);
        tok.transferFrom(alice, bob, 5);
        assertEq(tok.balanceOf(bob), 5);
    }

    /// ADR 0019 §6: a FROZEN asset still lets holders move tokens.
    function test_TransferWhenAssetFrozenSucceeds() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        assetRegistry.freeze(ASSET_ID, "incident");
        vm.prank(alice);
        tok.transfer(bob, 4);
        assertEq(tok.balanceOf(bob), 4);
    }

    /// ADR 0021: a stale reserve still lets holders move tokens.
    function test_TransferWhenReserveStaleSucceeds() public {
        _live();
        _mint(alice, 10);
        vm.warp(block.timestamp + 30 days);
        vm.prank(alice);
        tok.transfer(bob, 4);
        assertEq(tok.balanceOf(bob), 4);
    }

    /// T-REX: the sender's own verification is not re-checked, so a lapsed holder can exit.
    function test_UnverifiedSenderCanExitToVerified() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        ir.deleteIdentity(alice);
        vm.prank(alice);
        tok.transfer(bob, 10);
        assertEq(tok.balanceOf(bob), 10);
    }

    // ---------------------------------------------------------------- burn

    function test_BurnReleasesFrozenShortfall() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        tok.freezePartialTokens(alice, 8);
        vm.expectEmit(true, false, false, true, address(tok));
        emit IERC3643.TokensUnfrozen(alice, 3);
        vm.prank(irAgent);
        tok.burn(alice, 5);
        assertEq(tok.balanceOf(alice), 5);
        assertEq(tok.getFrozenTokens(alice), 5);
    }

    function test_BurnAllowedWhenAssetFrozen() public {
        _live();
        _mint(alice, 10);
        vm.startPrank(irAgent);
        assetRegistry.freeze(ASSET_ID, "x");
        tok.burn(alice, 10);
        vm.stopPrank();
        assertEq(tok.totalSupply(), 0);
    }

    // ---------------------------------------------------------------- freeze / pause (T3.2)

    function test_PartialFreezeBounds() public {
        _live();
        _mint(alice, 10);
        vm.startPrank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(Token.FreezeExceedsBalance.selector, alice, 10, 11));
        tok.freezePartialTokens(alice, 11);
        tok.freezePartialTokens(alice, 6);
        vm.expectRevert(abi.encodeWithSelector(Token.UnfreezeExceedsFrozen.selector, alice, 6, 7));
        tok.unfreezePartialTokens(alice, 7);
        tok.unfreezePartialTokens(alice, 6);
        vm.stopPrank();
        assertEq(tok.getFrozenTokens(alice), 0);
    }

    function test_SetAddressFrozenEmits() public {
        vm.expectEmit(true, true, true, false, address(tok));
        emit IERC3643.AddressFrozen(alice, true, irAgent);
        vm.prank(irAgent);
        tok.setAddressFrozen(alice, true);
        assertTrue(tok.isFrozen(alice));
    }

    function test_PauseNoOpsRevert() public {
        vm.startPrank(irAgent);
        vm.expectRevert(Token.TokenNotPaused.selector);
        tok.unpause();
        tok.pause();
        vm.expectRevert(Token.TokenAlreadyPaused.selector);
        tok.pause();
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- forced transfer (T3.3)

    function test_ForcedTransferTimelock() public {
        _live();
        _mint(alice, 10);
        bytes32 id = keccak256(abi.encode(alice, bob, uint256(4)));
        uint64 eta = uint64(block.timestamp) + 2 days;

        vm.expectEmit(true, false, false, true, address(tok));
        emit Token.ForcedTransferScheduled(id, alice, bob, 4, Token.ForcedTransferReason.COURT_ORDER, eta);
        vm.prank(govOwner);
        tok.scheduleForcedTransfer(alice, bob, 4, Token.ForcedTransferReason.COURT_ORDER);
        assertEq(tok.forcedTransferEta(alice, bob, 4), eta);

        vm.prank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(Token.ForcedTransferTimelocked.selector, id, eta));
        tok.forcedTransfer(alice, bob, 4);

        vm.warp(eta);
        vm.startPrank(irAgent);
        tok.setAddressFrozen(alice, true); // forced ignores frozen wallets and pause
        tok.pause();
        vm.stopPrank();
        vm.expectEmit(true, false, false, false, address(tok));
        emit Token.ForcedTransferExecuted(id);
        vm.prank(govOwner);
        assertTrue(tok.forcedTransfer(alice, bob, 4));
        assertEq(tok.balanceOf(bob), 4);
        assertEq(tok.forcedTransferEta(alice, bob, 4), 0);

        vm.prank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(Token.ForcedTransferNotScheduled.selector, id));
        tok.forcedTransfer(alice, bob, 4);
    }

    function test_ForcedTransferReleasesFrozenTokens() public {
        _live();
        _mint(alice, 10);
        vm.prank(irAgent);
        tok.freezePartialTokens(alice, 10);
        vm.prank(govOwner);
        tok.scheduleForcedTransfer(alice, bob, 6, Token.ForcedTransferReason.REGULATORY_ACTION);
        vm.warp(block.timestamp + 2 days);
        vm.prank(govOwner);
        tok.forcedTransfer(alice, bob, 6);
        assertEq(tok.getFrozenTokens(alice), 4);
        assertEq(tok.balanceOf(alice), 4);
    }

    function test_ForcedTransferToUnverifiedReverts() public {
        _live();
        _mint(alice, 10);
        vm.prank(govOwner);
        tok.scheduleForcedTransfer(alice, carol, 1, Token.ForcedTransferReason.ERRONEOUS_TRANSFER);
        vm.warp(block.timestamp + 2 days);
        vm.prank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(Token.ReceiverNotVerified.selector, carol));
        tok.forcedTransfer(alice, carol, 1);
    }

    function test_ForcedTransferCancelAndDoubleSchedule() public {
        bytes32 id = keccak256(abi.encode(alice, bob, uint256(1)));
        vm.startPrank(govOwner);
        tok.scheduleForcedTransfer(alice, bob, 1, Token.ForcedTransferReason.COURT_ORDER);
        vm.expectRevert(abi.encodeWithSelector(Token.ForcedTransferAlreadyScheduled.selector, id));
        tok.scheduleForcedTransfer(alice, bob, 1, Token.ForcedTransferReason.COURT_ORDER);
        vm.expectEmit(true, false, false, false, address(tok));
        emit Token.ForcedTransferCancelled(id);
        tok.cancelForcedTransfer(alice, bob, 1);
        vm.expectRevert(abi.encodeWithSelector(Token.ForcedTransferNotScheduled.selector, id));
        tok.cancelForcedTransfer(alice, bob, 1);
        vm.warp(block.timestamp + 3 days);
        vm.expectRevert(abi.encodeWithSelector(Token.ForcedTransferNotScheduled.selector, id));
        tok.forcedTransfer(alice, bob, 1);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- recovery (T3.3)

    function test_RecoveryHappyPath() public {
        _live();
        _mint(alice, 10);
        vm.startPrank(irAgent);
        tok.freezePartialTokens(alice, 3);
        tok.setAddressFrozen(alice, true);
        vm.stopPrank();

        IIdentity aliceId = ir.identity(alice);
        address newWallet = makeAddr("alice-new");
        vm.prank(alice);
        aliceId.addKey(keccak256(abi.encode(newWallet)), 1, 1);

        vm.expectEmit(true, true, true, false, address(tok));
        emit IERC3643.RecoverySuccess(alice, newWallet, address(aliceId));
        vm.prank(govOwner);
        assertTrue(tok.recoveryAddress(alice, newWallet, address(aliceId)));

        assertEq(tok.balanceOf(newWallet), 10);
        assertEq(tok.balanceOf(alice), 0);
        assertEq(tok.getFrozenTokens(newWallet), 3);
        assertEq(tok.getFrozenTokens(alice), 0);
        assertTrue(tok.isFrozen(newWallet));
        assertTrue(ir.isVerified(newWallet));
        assertFalse(ir.contains(alice));
        assertEq(ir.investorCountry(newWallet), 586);
    }

    function test_RecoveryGuards() public {
        _live();
        _mint(alice, 10);
        IIdentity aliceId = ir.identity(alice);
        IIdentity bobId = ir.identity(bob);
        address newWallet = makeAddr("alice-new");

        vm.startPrank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(Token.RecoveryIdentityMismatch.selector, alice, address(bobId)));
        tok.recoveryAddress(alice, newWallet, address(bobId));
        vm.expectRevert(abi.encodeWithSelector(Token.RecoveryKeyNotOnIdentity.selector, newWallet));
        tok.recoveryAddress(alice, newWallet, address(aliceId));
        vm.stopPrank();

        vm.prank(bob);
        bobId.addKey(keccak256(abi.encode(newWallet)), 1, 1);
        vm.prank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(Token.NothingToRecover.selector, bob));
        tok.recoveryAddress(bob, newWallet, address(bobId));
    }

    // ---------------------------------------------------------------- batches (T3.4)

    function test_BatchMintAndTransfer() public {
        _live();
        address[] memory to = new address[](2);
        uint256[] memory amt = new uint256[](2);
        to[0] = alice;
        to[1] = bob;
        amt[0] = 5;
        amt[1] = 7;
        vm.prank(irAgent);
        tok.batchMint(to, amt);
        assertEq(tok.balanceOf(alice) + tok.balanceOf(bob), 12);

        address[] memory to2 = new address[](1);
        uint256[] memory amt2 = new uint256[](1);
        to2[0] = bob;
        amt2[0] = 5;
        vm.prank(alice);
        tok.batchTransfer(to2, amt2);
        assertEq(tok.balanceOf(bob), 12);
    }

    function test_BatchLengthMismatchAndCap() public {
        vm.startPrank(irAgent);
        vm.expectRevert(Token.ArrayLengthMismatch.selector);
        tok.batchMint(new address[](2), new uint256[](1));
        vm.expectRevert(abi.encodeWithSelector(Token.BatchTooLarge.selector, 101));
        tok.batchMint(new address[](101), new uint256[](101));
        vm.expectRevert(Token.ArrayLengthMismatch.selector);
        tok.batchSetAddressFrozen(new address[](1), new bool[](2));
        vm.expectRevert(Token.ArrayLengthMismatch.selector);
        tok.batchBurn(new address[](1), new uint256[](0));
        vm.expectRevert(Token.ArrayLengthMismatch.selector);
        tok.batchFreezePartialTokens(new address[](1), new uint256[](0));
        vm.expectRevert(Token.ArrayLengthMismatch.selector);
        tok.batchUnfreezePartialTokens(new address[](1), new uint256[](0));
        vm.stopPrank();
        vm.prank(govOwner);
        vm.expectRevert(Token.ArrayLengthMismatch.selector);
        tok.batchForcedTransfer(new address[](1), new address[](1), new uint256[](2));
    }

    function test_BatchIsAllOrNothing() public {
        _live();
        address[] memory to = new address[](2);
        uint256[] memory amt = new uint256[](2);
        to[0] = alice;
        to[1] = carol; // unverified: second element fails
        amt[0] = 5;
        amt[1] = 5;
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(Token.ReceiverNotVerified.selector, carol));
        tok.batchMint(to, amt);
        assertEq(tok.balanceOf(alice), 0);
    }

    function test_BatchFreezeAndForced() public {
        _live();
        _mint(alice, 10);
        address[] memory w = new address[](1);
        w[0] = alice;
        uint256[] memory a = new uint256[](1);
        a[0] = 4;
        bool[] memory f = new bool[](1);
        f[0] = true;
        vm.startPrank(irAgent);
        tok.batchFreezePartialTokens(w, a);
        tok.batchUnfreezePartialTokens(w, a);
        tok.batchSetAddressFrozen(w, f);
        tok.batchBurn(w, a);
        vm.stopPrank();
        assertTrue(tok.isFrozen(alice));
        assertEq(tok.balanceOf(alice), 6);

        address[] memory to = new address[](1);
        to[0] = bob;
        vm.prank(govOwner);
        tok.scheduleForcedTransfer(alice, bob, 4, Token.ForcedTransferReason.COURT_ORDER);
        vm.warp(block.timestamp + 2 days);
        vm.prank(govOwner);
        tok.batchForcedTransfer(w, to, a);
        assertEq(tok.balanceOf(bob), 4);
    }

    // ---------------------------------------------------------------- owner setters

    function test_OwnerSetters() public {
        vm.startPrank(govOwner);
        tok.setName("New");
        tok.setSymbol("NEW");
        tok.setOnchainID(address(0xABCD));
        vm.expectEmit(true, false, false, false, address(tok));
        emit IERC3643.IdentityRegistryAdded(address(ir));
        tok.setIdentityRegistry(address(ir));
        vm.expectRevert(OwnerAgentRoles.ZeroAddress.selector);
        tok.setIdentityRegistry(address(0));
        vm.expectRevert(OwnerAgentRoles.ZeroAddress.selector);
        tok.setCompliance(address(0));

        ModularCompliance next = new ModularCompliance(govOwner);
        tok.setCompliance(address(next));
        vm.stopPrank();
        assertEq(tok.name(), "New");
        assertEq(tok.symbol(), "NEW");
        assertEq(tok.onchainID(), address(0xABCD));
        assertEq(address(tok.compliance()), address(next));
        assertEq(next.getTokenBound(), address(tok));
        assertEq(mc.getTokenBound(), address(0));
    }

    // ---------------------------------------------------------------- gating

    function test_OwnerFunctionsGated() public {
        vm.startPrank(irAgent); // an agent is not the owner
        bytes memory e = abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, irAgent);
        vm.expectRevert(e);
        tok.setName("x");
        vm.expectRevert(e);
        tok.setSymbol("x");
        vm.expectRevert(e);
        tok.setOnchainID(address(1));
        vm.expectRevert(e);
        tok.setIdentityRegistry(address(1));
        vm.expectRevert(e);
        tok.setCompliance(address(1));
        vm.expectRevert(e);
        tok.addAgent(stranger);
        vm.expectRevert(e);
        tok.removeAgent(irAgent);
        vm.expectRevert(e);
        tok.scheduleForcedTransfer(alice, bob, 1, Token.ForcedTransferReason.COURT_ORDER);
        vm.expectRevert(e);
        tok.cancelForcedTransfer(alice, bob, 1);
        vm.expectRevert(e);
        tok.forcedTransfer(alice, bob, 1);
        vm.expectRevert(e);
        tok.batchForcedTransfer(new address[](1), new address[](1), new uint256[](1));
        vm.expectRevert(e);
        tok.recoveryAddress(alice, bob, address(1));
        vm.stopPrank();
    }

    function test_AgentFunctionsGated() public {
        vm.startPrank(govOwner); // the owner is not an agent
        bytes memory e = abi.encodeWithSelector(OwnerAgentRoles.NotAuthorisedAgent.selector, govOwner);
        vm.expectRevert(e);
        tok.mint(alice, 1);
        vm.expectRevert(e);
        tok.burn(alice, 1);
        vm.expectRevert(e);
        tok.pause();
        vm.expectRevert(e);
        tok.unpause();
        vm.expectRevert(e);
        tok.setAddressFrozen(alice, true);
        vm.expectRevert(e);
        tok.freezePartialTokens(alice, 1);
        vm.expectRevert(e);
        tok.unfreezePartialTokens(alice, 1);
        vm.expectRevert(e);
        tok.batchMint(new address[](1), new uint256[](1));
        vm.expectRevert(e);
        tok.batchBurn(new address[](1), new uint256[](1));
        vm.expectRevert(e);
        tok.batchSetAddressFrozen(new address[](1), new bool[](1));
        vm.expectRevert(e);
        tok.batchFreezePartialTokens(new address[](1), new uint256[](1));
        vm.expectRevert(e);
        tok.batchUnfreezePartialTokens(new address[](1), new uint256[](1));
        vm.stopPrank();
    }

    function test_ComplianceHooksOnlyFromToken() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotBoundToken.selector, stranger));
        IModularCompliance(address(mc)).created(alice, 1);
    }
}

/// @notice A compliance module that refuses everything (test only).
contract RefuseAll {
    function bindCompliance(address) external {}
    function unbindCompliance(address) external {}
    function moduleTransferAction(address, address, uint256) external {}
    function moduleMintAction(address, uint256) external {}
    function moduleBurnAction(address, uint256) external {}

    function moduleCheck(address, address, uint256, address) external pure returns (bool) {
        return false;
    }

    function isComplianceBound(address) external pure returns (bool) {
        return true;
    }

    function canComplianceBind(address) external pure returns (bool) {
        return true;
    }

    function isPlugAndPlay() external pure returns (bool) {
        return true;
    }

    function name() external pure returns (string memory) {
        return "RefuseAll";
    }
}
