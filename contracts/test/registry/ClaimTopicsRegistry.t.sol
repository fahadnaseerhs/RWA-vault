// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ClaimTopicsRegistry} from "../../src/registry/ClaimTopicsRegistry.sol";
import {IClaimTopicsRegistry} from "../../src/registry/interfaces/IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistryTest
 * @notice T1.3 unit tests. The headline property (AC-T1-5): the topic set is never empty,
 *         so `isVerified` can never become vacuously true.
 */
contract ClaimTopicsRegistryTest is Test {
    ClaimTopicsRegistry internal reg;
    address internal owner = makeAddr("owner (2-of-3 multisig)");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant OTHER_TOPIC = 7;

    function setUp() public {
        reg = new ClaimTopicsRegistry(owner);
    }

    function _topics() internal view returns (uint256[] memory) {
        return reg.getClaimTopics();
    }

    // ------------------------------------------------------------------
    // The permanent topic and the never-empty set (AC-T1-5)
    // ------------------------------------------------------------------

    /// Q24 = A: the KYC topic is 1, permanently (ADR 0029).
    function test_KycTopicIsOne() public view {
        assertEq(reg.KYC_TOPIC(), 1);
    }

    /// AC-T1-5: a fresh deployment already requires exactly the KYC topic; it cannot start empty.
    function test_DeploysSeededWithKycTopic() public view {
        uint256[] memory t = _topics();
        assertEq(t.length, 1);
        assertEq(t[0], reg.KYC_TOPIC());
    }

    /// AC-T1-5: the seed is emitted, so an indexer rebuilding the set from events sees it.
    function test_ConstructorEmitsSeedTopic() public {
        vm.expectEmit(true, false, false, false);
        emit IClaimTopicsRegistry.ClaimTopicAdded(1);
        new ClaimTopicsRegistry(owner);
    }

    /// AC-T1-5: removing the last remaining topic (always KYC) reverts as permanent, and the set is
    /// left intact. The TopicSetCannotBeEmpty backstop is unreachable here while permanence holds; it
    /// is demonstrated by the mutant that removes the permanence guard (T1 thread, M9).
    function test_RemovingLastTopicReverts() public {
        vm.prank(owner);
        vm.expectRevert(ClaimTopicsRegistry.KycTopicIsPermanent.selector);
        reg.removeClaimTopic(1);
        assertEq(_topics().length, 1);
    }

    /// AC-T1-16: the KYC topic cannot be removed even when other topics remain; the set is left intact.
    function test_KycTopicCannotBeRemovedWhileOthersRemain() public {
        vm.startPrank(owner);
        reg.addClaimTopic(OTHER_TOPIC);
        vm.expectRevert(ClaimTopicsRegistry.KycTopicIsPermanent.selector);
        reg.removeClaimTopic(1);
        vm.stopPrank();
        uint256[] memory t = _topics();
        assertEq(t.length, 2);
        assertEq(t[0], 1);
    }

    // ------------------------------------------------------------------
    // Adding and removing
    // ------------------------------------------------------------------

    function test_AddClaimTopic() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IClaimTopicsRegistry.ClaimTopicAdded(OTHER_TOPIC);
        reg.addClaimTopic(OTHER_TOPIC);
        uint256[] memory t = _topics();
        assertEq(t.length, 2);
        assertEq(t[1], OTHER_TOPIC);
    }

    function test_RemoveClaimTopic() public {
        vm.startPrank(owner);
        reg.addClaimTopic(OTHER_TOPIC);
        vm.expectEmit(true, false, false, false);
        emit IClaimTopicsRegistry.ClaimTopicRemoved(OTHER_TOPIC);
        reg.removeClaimTopic(OTHER_TOPIC);
        vm.stopPrank();
        uint256[] memory t = _topics();
        assertEq(t.length, 1);
        assertEq(t[0], 1);
    }

    function test_AddDuplicateTopicReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.ClaimTopicAlreadyExists.selector, uint256(1)));
        reg.addClaimTopic(1);
    }

    function test_RemoveUnknownTopicReverts() public {
        vm.startPrank(owner);
        reg.addClaimTopic(OTHER_TOPIC);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.ClaimTopicNotFound.selector, uint256(99)));
        reg.removeClaimTopic(99);
        vm.stopPrank();
    }

    /// isVerified loops over every topic, so the set is bounded.
    function test_TopicSetIsBounded() public {
        uint256 max = reg.MAX_CLAIM_TOPICS();
        vm.startPrank(owner);
        for (uint256 i = 2; i <= max; i++) {
            reg.addClaimTopic(i);
        }
        assertEq(_topics().length, max);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.TooManyClaimTopics.selector, max));
        reg.addClaimTopic(max + 1);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Owner (ADR 0015, T1 spec §6)
    // ------------------------------------------------------------------

    function test_OnlyOwnerCanAddTopic() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.NotOwner.selector, stranger));
        reg.addClaimTopic(OTHER_TOPIC);
    }

    function test_OnlyOwnerCanRemoveTopic() public {
        vm.prank(owner);
        reg.addClaimTopic(OTHER_TOPIC);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.NotOwner.selector, stranger));
        reg.removeClaimTopic(OTHER_TOPIC);
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.InvalidOwner.selector, address(0)));
        new ClaimTopicsRegistry(address(0));
    }

    function test_OwnerIsTheConstructorArgument() public view {
        assertEq(reg.owner(), owner);
    }
}
