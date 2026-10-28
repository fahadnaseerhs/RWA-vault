// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IdentityFixtures} from "../identity/IdentityFixtures.sol";
import {IIdentity} from "../../src/identity/interfaces/IIdentity.sol";
import {IClaimIssuer} from "../../src/identity/interfaces/IClaimIssuer.sol";
import {IIdentityRegistry} from "../../src/registry/interfaces/IIdentityRegistry.sol";
import {ClaimTopicsRegistry} from "../../src/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../../src/registry/IdentityRegistryStorage.sol";
import {IdentityRegistry} from "../../src/registry/IdentityRegistry.sol";
import {OwnerAgentRoles} from "../../src/access/OwnerAgentRoles.sol";
import {KYC_TOPIC} from "../../src/registry/ClaimTopics.sol";

/// @notice A contract whose every call reverts: stands in for a hostile identity or issuer.
contract Reverter {
    fallback() external {
        revert("hostile");
    }
}

/**
 * @title IdentityRegistryTest
 * @notice T1.3–T1.6 per the T1 build spec §4–§7: registries, `isVerified`, and the matrix.
 */
contract IdentityRegistryTest is IdentityFixtures {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _deployIdentityLayer();
    }

    function test_KycTopicIsOne() public pure {
        assertEq(KYC_TOPIC, 1);
    }

    // ---------------------------------------------------------------- §7 matrix

    function test_VerifiedWithValidKycClaim() public {
        _onboardInvestor(alice, 586);
        assertTrue(ir.contains(alice));
        assertTrue(ir.isVerified(alice));
        assertEq(ir.investorCountry(alice), 586);
    }

    function test_UnregisteredWalletUnverified() public view {
        assertFalse(ir.contains(alice));
        assertFalse(ir.isVerified(alice));
    }

    function test_RegisteredWithoutClaimUnverified() public {
        IIdentity id = _newIdentity(alice);
        vm.prank(irAgent);
        ir.registerIdentity(alice, id, 586);
        assertFalse(ir.isVerified(alice));
    }

    function test_ClaimFromUntrustedIssuerUnverified() public {
        uint256 roguePk = 0xB0B;
        IClaimIssuer rogue = _newClaimIssuer(makeAddr("rogue-manager"), vm.addr(roguePk));
        IIdentity id = _newIdentity(alice);
        _addClaim(alice, id, rogue, roguePk, KYC);
        vm.prank(irAgent);
        ir.registerIdentity(alice, id, 586);
        assertFalse(ir.isVerified(alice));
    }

    function test_IssuerTrustedForOtherTopicUnverified() public {
        uint256 otherPk = 0xC0C;
        IClaimIssuer other = _newClaimIssuer(makeAddr("other-manager"), vm.addr(otherPk));
        uint256[] memory t = new uint256[](1);
        t[0] = KYC + 1;
        vm.prank(govOwner);
        issuers.addTrustedIssuer(other, t);
        IIdentity id = _newIdentity(alice);
        _addClaim(alice, id, other, otherPk, KYC);
        vm.prank(irAgent);
        ir.registerIdentity(alice, id, 586);
        assertFalse(ir.isVerified(alice));
    }

    function test_RevokedClaimUnverified() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _addClaim(alice, id, kycIssuer, issuerSignerPk, KYC);
        vm.prank(irAgent);
        ir.registerIdentity(alice, id, 586);
        assertTrue(ir.isVerified(alice));
        vm.prank(issuerManager);
        kycIssuer.revokeClaimBySignature(sig);
        assertFalse(ir.isVerified(alice));
    }

    function test_IssuerRemovedFromRegistryUnverified() public {
        _onboardInvestor(alice, 586);
        vm.prank(govOwner);
        issuers.removeTrustedIssuer(kycIssuer);
        assertFalse(ir.isVerified(alice));
    }

    function test_IssuerTopicsUpdatedWithoutKycUnverified() public {
        _onboardInvestor(alice, 586);
        uint256[] memory t = new uint256[](1);
        t[0] = KYC + 1;
        vm.prank(govOwner);
        issuers.updateIssuerClaimTopics(kycIssuer, t);
        assertFalse(ir.isVerified(alice));
    }

    function test_IssuerClaimKeyRemovedUnverified() public {
        _onboardInvestor(alice, 586);
        vm.prank(issuerManager);
        kycIssuer.removeKey(keccak256(abi.encode(issuerSigner)), CLAIM_PURPOSE);
        assertFalse(ir.isVerified(alice));
    }

    function test_ClaimRemovedFromIdentityUnverified() public {
        IIdentity id = _onboardInvestor(alice, 586);
        vm.prank(alice);
        id.removeClaim(keccak256(abi.encode(address(kycIssuer), KYC)));
        assertFalse(ir.isVerified(alice));
    }

    function test_RevertingIssuerMakesWalletUnverifiedNotRevert() public {
        Reverter bad = new Reverter();
        uint256[] memory t = new uint256[](1);
        t[0] = KYC;
        vm.startPrank(govOwner);
        issuers.removeTrustedIssuer(kycIssuer);
        issuers.addTrustedIssuer(IClaimIssuer(address(bad)), t);
        vm.stopPrank();
        IIdentity id = _newIdentity(alice);
        vm.prank(irAgent);
        ir.registerIdentity(alice, id, 586);
        assertFalse(ir.isVerified(alice));
    }

    function test_RevertingIdentityMakesWalletUnverifiedNotRevert() public {
        Reverter bad = new Reverter();
        vm.prank(irAgent);
        ir.registerIdentity(alice, IIdentity(address(bad)), 586);
        assertFalse(ir.isVerified(alice));
    }

    function test_RevertingTopicsRegistryMakesWalletUnverifiedNotRevert() public {
        _onboardInvestor(alice, 586);
        Reverter bad = new Reverter();
        vm.prank(govOwner);
        ir.setClaimTopicsRegistry(address(bad));
        assertFalse(ir.isVerified(alice));
    }

    function test_CountryUpdateDoesNotChangeVerification() public {
        _onboardInvestor(alice, 586);
        vm.expectEmit(true, true, false, false, address(ir));
        emit IIdentityRegistry.CountryUpdated(alice, 840);
        vm.prank(irAgent);
        ir.updateCountry(alice, 840);
        assertEq(ir.investorCountry(alice), 840);
        assertTrue(ir.isVerified(alice));
    }

    function test_DeleteIdentityUnverifies() public {
        IIdentity id = _onboardInvestor(alice, 586);
        vm.expectEmit(true, true, false, false, address(ir));
        emit IIdentityRegistry.IdentityRemoved(alice, id);
        vm.prank(irAgent);
        ir.deleteIdentity(alice);
        assertFalse(ir.contains(alice));
        assertFalse(ir.isVerified(alice));
    }

    function test_SharedStorageAcrossTwoRegistries() public {
        _onboardInvestor(alice, 586);
        IdentityRegistry ir2 = new IdentityRegistry(govOwner, issuers, topics, irs);
        assertTrue(ir2.isVerified(alice)); // ADR 0016
    }

    function test_EmptyTopicListVerifiesRegisteredWallet() public {
        IIdentity id = _newIdentity(alice);
        vm.prank(irAgent);
        ir.registerIdentity(alice, id, 586);
        vm.prank(govOwner);
        topics.removeClaimTopic(KYC);
        assertTrue(ir.isVerified(alice));
    }

    function test_UpdateIdentity() public {
        IIdentity first = _onboardInvestor(alice, 586);
        IIdentity second = _newIdentity(alice);
        vm.expectEmit(true, true, false, false, address(ir));
        emit IIdentityRegistry.IdentityUpdated(first, second);
        vm.prank(irAgent);
        ir.updateIdentity(alice, second);
        assertEq(address(ir.identity(alice)), address(second));
        assertFalse(ir.isVerified(alice));
    }

    function test_UpdateIdentityToZeroReverts() public {
        _onboardInvestor(alice, 586);
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidIdentity.selector, address(0)));
        ir.updateIdentity(alice, IIdentity(address(0)));
    }

    function test_RegisterTwiceReverts() public {
        _onboardInvestor(alice, 586);
        IIdentity other = _newIdentity(alice);
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityAlreadyStored.selector, alice));
        ir.registerIdentity(alice, other, 586);
    }

    function test_RegisterZeroWalletOrIdentityReverts() public {
        IIdentity id = _newIdentity(alice);
        vm.startPrank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidWallet.selector, address(0)));
        ir.registerIdentity(address(0), id, 586);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidIdentity.selector, address(0)));
        ir.registerIdentity(alice, IIdentity(address(0)), 586);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityNotStored.selector, bob));
        ir.deleteIdentity(bob);
        vm.stopPrank();
    }

    function test_BatchRegister() public {
        address[] memory users = new address[](2);
        IIdentity[] memory ids = new IIdentity[](2);
        uint16[] memory countries = new uint16[](2);
        users[0] = alice;
        users[1] = bob;
        ids[0] = _newIdentity(alice);
        ids[1] = _newIdentity(bob);
        countries[0] = 586;
        countries[1] = 840;
        vm.prank(irAgent);
        ir.batchRegisterIdentity(users, ids, countries);
        assertTrue(ir.contains(alice) && ir.contains(bob));

        vm.prank(irAgent);
        vm.expectRevert(IdentityRegistry.LengthMismatch.selector);
        ir.batchRegisterIdentity(users, ids, new uint16[](1));
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, address(0)));
        new IdentityRegistry(address(0), issuers, topics, irs);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.NotOwner.selector, address(0)));
        new ClaimTopicsRegistry(address(0));
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, address(0)));
        new TrustedIssuersRegistry(address(0));
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, address(0)));
        new IdentityRegistryStorage(address(0));
    }

    // ---------------------------------------------------------------- gating

    function test_RegistryAgentAndOwnerGates() public {
        IIdentity id = _newIdentity(alice);
        address[] memory users = new address[](0);
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAuthorisedAgent.selector, stranger));
        ir.registerIdentity(alice, id, 1);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAuthorisedAgent.selector, stranger));
        ir.batchRegisterIdentity(users, new IIdentity[](0), new uint16[](0));
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAuthorisedAgent.selector, stranger));
        ir.deleteIdentity(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAuthorisedAgent.selector, stranger));
        ir.updateCountry(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAuthorisedAgent.selector, stranger));
        ir.updateIdentity(alice, id);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.setClaimTopicsRegistry(address(topics));
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.setTrustedIssuersRegistry(address(issuers));
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.setIdentityRegistryStorage(address(irs));
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.addAgent(stranger);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.removeAgent(irAgent);
        vm.stopPrank();
    }

    function test_RegistrySettersRejectZero() public {
        vm.startPrank(govOwner);
        vm.expectRevert(OwnerAgentRoles.ZeroAddress.selector);
        ir.setClaimTopicsRegistry(address(0));
        vm.expectRevert(OwnerAgentRoles.ZeroAddress.selector);
        ir.setTrustedIssuersRegistry(address(0));
        vm.expectRevert(OwnerAgentRoles.ZeroAddress.selector);
        ir.setIdentityRegistryStorage(address(0));
        vm.stopPrank();
    }

    function test_AgentManagementNotIdempotent() public {
        vm.startPrank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.AgentUnchanged.selector, irAgent));
        ir.addAgent(irAgent);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.InvalidAgent.selector, address(0)));
        ir.addAgent(address(0));
        ir.removeAgent(irAgent);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.AgentUnchanged.selector, irAgent));
        ir.removeAgent(irAgent);
        vm.stopPrank();
        assertFalse(ir.isAgent(irAgent));
    }

    function test_StorageWritesOnlyFromBoundRegistry() public {
        IIdentity id = _newIdentity(alice);
        vm.startPrank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, irAgent));
        irs.addIdentityToStorage(alice, id, 1);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, irAgent));
        irs.removeIdentityFromStorage(alice);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, irAgent));
        irs.modifyStoredInvestorCountry(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, irAgent));
        irs.modifyStoredIdentity(alice, id);
        vm.stopPrank();

        vm.prank(govOwner);
        irs.unbindIdentityRegistry(address(ir));
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, address(ir)));
        ir.registerIdentity(alice, id, 1);
    }

    function test_StorageBinding() public {
        vm.startPrank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.RegistryAlreadyBound.selector, address(ir)));
        irs.bindIdentityRegistry(address(ir));
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidRegistry.selector, address(0)));
        irs.bindIdentityRegistry(address(0));
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.RegistryNotBound.selector, stranger));
        irs.unbindIdentityRegistry(stranger);
        vm.stopPrank();
        assertEq(irs.linkedIdentityRegistries().length, 1);

        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, stranger));
        irs.bindIdentityRegistry(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, stranger));
        irs.unbindIdentityRegistry(address(ir));
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- T1.3 topics

    function test_TopicsRegistry() public {
        assertEq(topics.getClaimTopics().length, 1);
        assertEq(topics.getClaimTopics()[0], KYC);
        vm.startPrank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.ClaimTopicAlreadyExists.selector, KYC));
        topics.addClaimTopic(KYC);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.ClaimTopicNotFound.selector, uint256(99)));
        topics.removeClaimTopic(99);
        for (uint256 i = 2; i <= 15; ++i) {
            topics.addClaimTopic(i);
        }
        vm.expectRevert(ClaimTopicsRegistry.TooManyClaimTopics.selector);
        topics.addClaimTopic(16);
        vm.stopPrank();

        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.NotOwner.selector, stranger));
        topics.addClaimTopic(77);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.NotOwner.selector, stranger));
        topics.removeClaimTopic(KYC);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- T1.4 trusted issuers

    function test_TrustedIssuersRegistry() public {
        assertTrue(issuers.isTrustedIssuer(address(kycIssuer)));
        assertTrue(issuers.hasClaimTopic(address(kycIssuer), KYC));
        assertFalse(issuers.hasClaimTopic(address(kycIssuer), KYC + 1));
        assertEq(issuers.getTrustedIssuersForClaimTopic(KYC).length, 1);

        uint256[] memory t = new uint256[](2);
        t[0] = KYC + 1;
        t[1] = KYC + 2;
        vm.startPrank(govOwner);
        issuers.updateIssuerClaimTopics(kycIssuer, t);
        assertEq(issuers.getTrustedIssuersForClaimTopic(KYC).length, 0);
        assertEq(issuers.getTrustedIssuersForClaimTopic(KYC + 2).length, 1);
        assertEq(issuers.getTrustedIssuerClaimTopics(kycIssuer).length, 2);

        vm.expectRevert(
            abi.encodeWithSelector(TrustedIssuersRegistry.IssuerAlreadyTrusted.selector, address(kycIssuer))
        );
        issuers.addTrustedIssuer(kycIssuer, t);
        vm.expectRevert(TrustedIssuersRegistry.EmptyClaimTopics.selector);
        issuers.updateIssuerClaimTopics(kycIssuer, new uint256[](0));
        vm.expectRevert(TrustedIssuersRegistry.TooManyClaimTopics.selector);
        issuers.updateIssuerClaimTopics(kycIssuer, new uint256[](16));
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.InvalidIssuer.selector, address(0)));
        issuers.addTrustedIssuer(IClaimIssuer(address(0)), t);

        issuers.removeTrustedIssuer(kycIssuer);
        assertFalse(issuers.isTrustedIssuer(address(kycIssuer)));
        assertEq(issuers.getTrustedIssuers().length, 0);
        assertEq(issuers.getTrustedIssuersForClaimTopic(KYC + 1).length, 0);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerNotTrusted.selector, address(kycIssuer)));
        issuers.removeTrustedIssuer(kycIssuer);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerNotTrusted.selector, address(kycIssuer)));
        issuers.updateIssuerClaimTopics(kycIssuer, t);
        vm.stopPrank();
    }

    function test_TrustedIssuersCap() public {
        uint256[] memory t = new uint256[](1);
        t[0] = KYC;
        vm.startPrank(govOwner);
        for (uint256 i = 1; i < 50; ++i) {
            issuers.addTrustedIssuer(IClaimIssuer(address(uint160(0x10000 + i))), t);
        }
        vm.expectRevert(TrustedIssuersRegistry.TooManyIssuers.selector);
        issuers.addTrustedIssuer(IClaimIssuer(address(0xFFFFF)), t);
        vm.stopPrank();
    }

    function test_TrustedIssuersOnlyOwner() public {
        uint256[] memory t = new uint256[](1);
        t[0] = KYC;
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        issuers.addTrustedIssuer(IClaimIssuer(stranger), t);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        issuers.removeTrustedIssuer(kycIssuer);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        issuers.updateIssuerClaimTopics(kycIssuer, t);
        vm.stopPrank();
    }
}
