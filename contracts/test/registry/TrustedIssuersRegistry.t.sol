// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IClaimIssuer} from "../../src/vendor/onchain-id/interface/IClaimIssuer.sol";
import {TrustedIssuersRegistry} from "../../src/registry/TrustedIssuersRegistry.sol";
import {ITrustedIssuersRegistry} from "../../src/registry/interfaces/ITrustedIssuersRegistry.sol";

/// @dev Minimal contract so the address has code (passes extcodesize check).
contract DummyIssuer {
    fallback() external payable {}
}

/**
 * @title TrustedIssuersRegistryTest
 * @notice T1.4 unit tests. The headline properties:
 *         - AC-T1-26: empty topic array reverts.
 *         - AC-T1-27: no-code address reverts.
 *         - AC-T1-28: `getTrustedIssuersForClaimTopic` returns only matching issuers.
 *         - AC-T1-29: cap on issuers per topic.
 */
contract TrustedIssuersRegistryTest is Test {
    TrustedIssuersRegistry internal reg;
    address internal owner = makeAddr("owner (2-of-3 multisig)");
    address internal stranger = makeAddr("stranger");

    IClaimIssuer internal issuerA;
    IClaimIssuer internal issuerB;
    IClaimIssuer internal issuerC;

    uint256 internal constant KYC_TOPIC = 1;
    uint256 internal constant AML_TOPIC = 7;

    function setUp() public {
        reg = new TrustedIssuersRegistry(owner);
        issuerA = IClaimIssuer(address(new DummyIssuer()));
        issuerB = IClaimIssuer(address(new DummyIssuer()));
        issuerC = IClaimIssuer(address(new DummyIssuer()));
    }

    function _kycTopics() internal pure returns (uint256[] memory t) {
        t = new uint256[](1);
        t[0] = KYC_TOPIC;
    }

    function _amlTopics() internal pure returns (uint256[] memory t) {
        t = new uint256[](1);
        t[0] = AML_TOPIC;
    }

    function _bothTopics() internal pure returns (uint256[] memory t) {
        t = new uint256[](2);
        t[0] = KYC_TOPIC;
        t[1] = AML_TOPIC;
    }

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------

    function test_OwnerIsTheConstructorArgument() public view {
        assertEq(reg.owner(), owner);
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.InvalidOwner.selector, address(0)));
        new TrustedIssuersRegistry(address(0));
    }

    function test_StartsEmpty() public view {
        assertEq(reg.getTrustedIssuers().length, 0);
    }

    // ------------------------------------------------------------------
    // addTrustedIssuer
    // ------------------------------------------------------------------

    function test_AddTrustedIssuer() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ITrustedIssuersRegistry.TrustedIssuerAdded(issuerA, _kycTopics());
        reg.addTrustedIssuer(issuerA, _kycTopics());

        assertTrue(reg.isTrustedIssuer(address(issuerA)), "issuer should be trusted");
        assertEq(reg.getTrustedIssuers().length, 1);
        assertEq(address(reg.getTrustedIssuers()[0]), address(issuerA));
    }

    /// AC-T1-26: empty topic array reverts.
    function test_AddWithEmptyTopicsReverts() public {
        uint256[] memory empty = new uint256[](0);
        vm.prank(owner);
        vm.expectRevert(TrustedIssuersRegistry.EmptyClaimTopics.selector);
        reg.addTrustedIssuer(issuerA, empty);
    }

    /// AC-T1-27: no-code address reverts.
    function test_AddWithNoCodeReverts() public {
        address noCode = makeAddr("no-code EOA");
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerHasNoCode.selector, noCode));
        reg.addTrustedIssuer(IClaimIssuer(noCode), _kycTopics());
    }

    function test_AddDuplicateIssuerReverts() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(issuerA, _kycTopics());
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerAlreadyExists.selector, address(issuerA)));
        reg.addTrustedIssuer(issuerA, _amlTopics());
        vm.stopPrank();
    }

    function test_AddWithDuplicateTopicsReverts() public {
        uint256[] memory dup = new uint256[](2);
        dup[0] = KYC_TOPIC;
        dup[1] = KYC_TOPIC;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.DuplicateClaimTopic.selector, KYC_TOPIC));
        reg.addTrustedIssuer(issuerA, dup);
    }

    // ------------------------------------------------------------------
    // Per-topic queries (AC-T1-28)
    // ------------------------------------------------------------------

    /// AC-T1-28: getTrustedIssuersForClaimTopic returns ONLY issuers for that topic.
    function test_GetIssuersForTopicReturnsOnlyMatching() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(issuerA, _kycTopics()); // KYC only
        reg.addTrustedIssuer(issuerB, _amlTopics()); // AML only
        reg.addTrustedIssuer(issuerC, _bothTopics()); // both
        vm.stopPrank();

        IClaimIssuer[] memory kycIssuers = reg.getTrustedIssuersForClaimTopic(KYC_TOPIC);
        assertEq(kycIssuers.length, 2, "KYC topic should have 2 issuers");
        // issuerA and issuerC, but order may vary due to array storage
        bool hasA;
        bool hasC;
        for (uint256 i = 0; i < kycIssuers.length; i++) {
            if (address(kycIssuers[i]) == address(issuerA)) hasA = true;
            if (address(kycIssuers[i]) == address(issuerC)) hasC = true;
        }
        assertTrue(hasA, "issuerA should be in KYC issuers");
        assertTrue(hasC, "issuerC should be in KYC issuers");

        IClaimIssuer[] memory amlIssuers = reg.getTrustedIssuersForClaimTopic(AML_TOPIC);
        assertEq(amlIssuers.length, 2, "AML topic should have 2 issuers");

        // Topic 99 should return empty.
        assertEq(reg.getTrustedIssuersForClaimTopic(99).length, 0, "unknown topic should have 0 issuers");
    }

    /// AC-T1-28 via hasClaimTopic: issuer trusted for AML, not for KYC.
    function test_HasClaimTopicDistinguishesTopics() public {
        vm.prank(owner);
        reg.addTrustedIssuer(issuerA, _amlTopics());
        assertTrue(reg.hasClaimTopic(address(issuerA), AML_TOPIC), "issuerA should have AML");
        assertFalse(reg.hasClaimTopic(address(issuerA), KYC_TOPIC), "issuerA should NOT have KYC");
    }

    function test_GetTrustedIssuerClaimTopics() public {
        vm.prank(owner);
        reg.addTrustedIssuer(issuerA, _bothTopics());
        uint256[] memory topics = reg.getTrustedIssuerClaimTopics(issuerA);
        assertEq(topics.length, 2);
        assertEq(topics[0], KYC_TOPIC);
        assertEq(topics[1], AML_TOPIC);
    }

    // ------------------------------------------------------------------
    // removeTrustedIssuer
    // ------------------------------------------------------------------

    function test_RemoveTrustedIssuer() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(issuerA, _bothTopics());
        vm.expectEmit(true, false, false, false);
        emit ITrustedIssuersRegistry.TrustedIssuerRemoved(issuerA);
        reg.removeTrustedIssuer(issuerA);
        vm.stopPrank();

        assertFalse(reg.isTrustedIssuer(address(issuerA)), "issuer should be removed");
        assertEq(reg.getTrustedIssuers().length, 0);
        assertEq(reg.getTrustedIssuersForClaimTopic(KYC_TOPIC).length, 0, "KYC topic should be empty");
        assertEq(reg.getTrustedIssuersForClaimTopic(AML_TOPIC).length, 0, "AML topic should be empty");
    }

    function test_RemoveNonExistentIssuerReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerNotFound.selector, address(issuerA)));
        reg.removeTrustedIssuer(issuerA);
    }

    /// Removing one issuer does not affect another under the same topic.
    function test_RemoveOneIssuerPreservesOther() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(issuerA, _kycTopics());
        reg.addTrustedIssuer(issuerB, _kycTopics());
        reg.removeTrustedIssuer(issuerA);
        vm.stopPrank();

        assertFalse(reg.isTrustedIssuer(address(issuerA)));
        assertTrue(reg.isTrustedIssuer(address(issuerB)));
        IClaimIssuer[] memory kycIssuers = reg.getTrustedIssuersForClaimTopic(KYC_TOPIC);
        assertEq(kycIssuers.length, 1);
        assertEq(address(kycIssuers[0]), address(issuerB));
    }

    // ------------------------------------------------------------------
    // updateIssuerClaimTopics
    // ------------------------------------------------------------------

    function test_UpdateIssuerClaimTopics() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(issuerA, _kycTopics());
        vm.expectEmit(true, false, false, true);
        emit ITrustedIssuersRegistry.ClaimTopicsUpdated(issuerA, _amlTopics());
        reg.updateIssuerClaimTopics(issuerA, _amlTopics());
        vm.stopPrank();

        // Issuer should now be under AML, not KYC.
        assertTrue(reg.hasClaimTopic(address(issuerA), AML_TOPIC), "should have AML after update");
        assertFalse(reg.hasClaimTopic(address(issuerA), KYC_TOPIC), "should NOT have KYC after update");
        assertEq(reg.getTrustedIssuersForClaimTopic(KYC_TOPIC).length, 0, "KYC should be empty");
        assertEq(reg.getTrustedIssuersForClaimTopic(AML_TOPIC).length, 1, "AML should have 1");
    }

    function test_UpdateNonExistentIssuerReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerNotFound.selector, address(issuerA)));
        reg.updateIssuerClaimTopics(issuerA, _kycTopics());
    }

    function test_UpdateWithEmptyTopicsReverts() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(issuerA, _kycTopics());
        uint256[] memory empty = new uint256[](0);
        vm.expectRevert(TrustedIssuersRegistry.EmptyClaimTopics.selector);
        reg.updateIssuerClaimTopics(issuerA, empty);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Cap (AC-T1-29)
    // ------------------------------------------------------------------

    /// AC-T1-29: cap on issuers per topic, tested at the bound.
    function test_IssuerCapPerTopic() public {
        uint256 max = reg.MAX_ISSUERS_PER_TOPIC();
        vm.startPrank(owner);
        // Fill topic to max.
        for (uint256 i = 0; i < max; i++) {
            DummyIssuer d = new DummyIssuer();
            reg.addTrustedIssuer(IClaimIssuer(address(d)), _kycTopics());
        }
        assertEq(reg.getTrustedIssuersForClaimTopic(KYC_TOPIC).length, max, "should be at cap");

        // One more should revert.
        DummyIssuer overflow = new DummyIssuer();
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.TooManyIssuersPerTopic.selector, KYC_TOPIC, max));
        reg.addTrustedIssuer(IClaimIssuer(address(overflow)), _kycTopics());
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Owner access (T1 spec §6, §12)
    // ------------------------------------------------------------------

    function test_OnlyOwnerCanAdd() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        reg.addTrustedIssuer(issuerA, _kycTopics());
    }

    function test_OnlyOwnerCanRemove() public {
        vm.prank(owner);
        reg.addTrustedIssuer(issuerA, _kycTopics());
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        reg.removeTrustedIssuer(issuerA);
    }

    function test_OnlyOwnerCanUpdate() public {
        vm.prank(owner);
        reg.addTrustedIssuer(issuerA, _kycTopics());
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        reg.updateIssuerClaimTopics(issuerA, _amlTopics());
    }
}
