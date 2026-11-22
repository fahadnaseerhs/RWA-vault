// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IClaimIssuer} from "../../src/vendor/onchain-id/interface/IClaimIssuer.sol";
import {TrustedIssuersRegistry} from "../../src/registry/TrustedIssuersRegistry.sol";
import {MockClaimIssuer} from "../mocks/MockClaimIssuer.sol";

/**
 * @title TrustedIssuersRegistryTest
 * @notice Unit tests for the PR #5 `TrustedIssuersRegistry` (Q29, Option 1). Owner-only writes.
 */
contract TrustedIssuersRegistryTest is Test {
    TrustedIssuersRegistry internal reg;
    address internal owner = makeAddr("owner (2-of-3 multisig)");
    address internal stranger = makeAddr("stranger");
    MockClaimIssuer internal issuerA;
    MockClaimIssuer internal issuerB;
    uint256 internal constant KYC = 1;
    uint256 internal constant AML = 2;

    function setUp() public {
        reg = new TrustedIssuersRegistry(owner);
        issuerA = new MockClaimIssuer();
        issuerB = new MockClaimIssuer();
    }

    function _topics(uint256 a) internal pure returns (uint256[] memory t) {
        t = new uint256[](1);
        t[0] = a;
    }

    function test_OwnerIsSet() public view {
        assertEq(reg.owner(), owner);
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.InvalidOwner.selector, address(0)));
        new TrustedIssuersRegistry(address(0));
    }

    function test_AddTrustedIssuer() public {
        vm.prank(owner);
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), _topics(KYC));
        assertTrue(reg.isTrustedIssuer(address(issuerA)));
        assertTrue(reg.hasClaimTopic(address(issuerA), KYC));
        assertFalse(reg.hasClaimTopic(address(issuerA), AML));
        assertEq(reg.getTrustedIssuers().length, 1);
        assertEq(reg.getTrustedIssuersForClaimTopic(KYC).length, 1);
    }

    function test_AddAlreadyTrustedReverts() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), _topics(KYC));
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerAlreadyTrusted.selector, address(issuerA)));
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), _topics(AML));
        vm.stopPrank();
    }

    function test_AddZeroIssuerReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.InvalidIssuer.selector, address(0)));
        reg.addTrustedIssuer(IClaimIssuer(address(0)), _topics(KYC));
    }

    function test_AddEmptyTopicsReverts() public {
        uint256[] memory none = new uint256[](0);
        vm.prank(owner);
        vm.expectRevert(TrustedIssuersRegistry.EmptyClaimTopics.selector);
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), none);
    }

    function test_OnlyOwnerCanAdd() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), _topics(KYC));
    }

    function test_RemoveTrustedIssuer() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), _topics(KYC));
        reg.removeTrustedIssuer(IClaimIssuer(address(issuerA)));
        vm.stopPrank();
        assertFalse(reg.isTrustedIssuer(address(issuerA)));
        assertEq(reg.getTrustedIssuersForClaimTopic(KYC).length, 0);
    }

    function test_RemoveNotTrustedReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerNotTrusted.selector, address(issuerA)));
        reg.removeTrustedIssuer(IClaimIssuer(address(issuerA)));
    }

    function test_UpdateClaimTopics() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), _topics(KYC));
        reg.updateIssuerClaimTopics(IClaimIssuer(address(issuerA)), _topics(AML));
        vm.stopPrank();
        assertFalse(reg.hasClaimTopic(address(issuerA), KYC));
        assertTrue(reg.hasClaimTopic(address(issuerA), AML));
        assertEq(reg.getTrustedIssuersForClaimTopic(KYC).length, 0);
        assertEq(reg.getTrustedIssuersForClaimTopic(AML).length, 1);
    }

    function test_TwoIssuersSameTopic() public {
        vm.startPrank(owner);
        reg.addTrustedIssuer(IClaimIssuer(address(issuerA)), _topics(KYC));
        reg.addTrustedIssuer(IClaimIssuer(address(issuerB)), _topics(KYC));
        vm.stopPrank();
        assertEq(reg.getTrustedIssuersForClaimTopic(KYC).length, 2);
    }
}
