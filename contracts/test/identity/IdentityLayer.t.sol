// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IdentityFixture} from "../helpers/IdentityFixture.sol";
import {IIdentity} from "../../src/identity/interfaces/IIdentity.sol";
import {IClaimIssuer} from "../../src/identity/interfaces/IClaimIssuer.sol";
import {IIdentityRegistry} from "../../src/registry/interfaces/IIdentityRegistry.sol";
import {ClaimTopicsRegistry} from "../../src/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../../src/registry/IdentityRegistryStorage.sol";
import {IdentityRegistry} from "../../src/registry/IdentityRegistry.sol";
import {OwnerAgentRoles} from "../../src/access/OwnerAgentRoles.sol";

/// @notice An "identity" whose every call reverts, to prove `isVerified` fails closed.
contract RevertingIdentity {
    fallback() external {
        revert("hostile");
    }
}

/**
 * @title IdentityLayerTest
 * @notice T1.1 vendoring smoke test, T1.2 ClaimIssuer adapter tests, T1.3/T1.4 registries,
 *         T1.5 `isVerified`, and the T1.6 matrix: verified / unverified, revoked claim,
 *         wrong issuer, country update.
 */
contract IdentityLayerTest is IdentityFixture {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        _deployIdentityLayer();
    }

    // ---------------------------------------------------------------- T1.1 / T1.2 vendored contracts

    function test_VendoredVersionIs221() public {
        IIdentity id = _newIdentity(alice);
        (bool ok, bytes memory ret) = address(id).staticcall(abi.encodeWithSignature("version()"));
        assertTrue(ok);
        assertEq(abi.decode(ret, (string)), "2.2.1");
    }

    function test_IdentityManagerKeyIsSet() public {
        IIdentity id = _newIdentity(alice);
        assertTrue(id.keyHasPurpose(keccak256(abi.encode(alice)), 1));
        assertFalse(id.keyHasPurpose(keccak256(abi.encode(bob)), 1));
    }

    function test_ClaimIssuerValidatesItsOwnSignature() public {
        IIdentity id = _newIdentity(alice);
        bytes memory data = "d";
        bytes memory sig = _signClaim(issuerSignerPk, id, KYC, data);
        assertTrue(kycIssuer.isClaimValid(id, KYC, sig, data));
        // Same signature, different topic or data: invalid.
        assertFalse(kycIssuer.isClaimValid(id, KYC + 1, sig, data));
        assertFalse(kycIssuer.isClaimValid(id, KYC, sig, "other"));
    }

    function test_ClaimIssuerRejectsUnknownSigner() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signClaim(0xBAD, id, KYC, "d");
        assertFalse(kycIssuer.isClaimValid(id, KYC, sig, "d"));
    }

    function test_ClaimIssuerRevocation() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signClaim(issuerSignerPk, id, KYC, "d");
        vm.prank(issuerManager);
        kycIssuer.revokeClaimBySignature(sig);
        assertTrue(kycIssuer.isClaimRevoked(sig));
        assertFalse(kycIssuer.isClaimValid(id, KYC, sig, "d"));
    }

    function test_ClaimIssuerRevokeOnlyManager() public {
        vm.prank(stranger);
        vm.expectRevert("Permissions: Sender does not have management key");
        kycIssuer.revokeClaimBySignature("x");
    }

    function test_IdentityRefusesClaimWithBadSignature() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signClaim(0xBAD, id, KYC, "d");
        vm.prank(alice);
        vm.expectRevert("invalid claim");
        id.addClaim(KYC, ECDSA_SCHEME, address(kycIssuer), sig, "d", "");
    }

    // ---------------------------------------------------------------- T1.6 matrix

    function test_VerifiedWallet() public {
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
        assertTrue(ir.contains(alice));
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

    function test_RemovingTrustedIssuerUnverifies() public {
        _onboardInvestor(alice, 586);
        vm.prank(govOwner);
        issuers.removeTrustedIssuer(kycIssuer);
        assertFalse(ir.isVerified(alice));
    }

    function test_SignerKeyRemovedUnverifies() public {
        _onboardInvestor(alice, 586);
        vm.prank(issuerManager);
        kycIssuer.removeKey(keccak256(abi.encode(issuerSigner)), CLAIM_PURPOSE);
        assertFalse(ir.isVerified(alice));
    }

    function test_ClaimRemovedFromIdentityUnverifies() public {
        IIdentity id = _onboardInvestor(alice, 586);
        vm.prank(alice);
        id.removeClaim(keccak256(abi.encode(address(kycIssuer), KYC)));
        assertFalse(ir.isVerified(alice));
    }

    function test_NoRequiredTopicsMeansRegisteredIsVerified() public {
        IIdentity id = _newIdentity(alice);
        vm.prank(irAgent);
        ir.registerIdentity(alice, id, 586);
        vm.prank(govOwner);
        topics.removeClaimTopic(KYC);
        assertTrue(ir.isVerified(alice));
    }

    function test_HostileIdentityFailsClosed() public {
        RevertingIdentity bad = new RevertingIdentity();
        vm.prank(irAgent);
        ir.registerIdentity(alice, IIdentity(address(bad)), 586);
        assertFalse(ir.isVerified(alice));
    }

    function test_CountryUpdate() public {
        _onboardInvestor(alice, 586);
        vm.expectEmit(true, true, false, false, address(ir));
        emit IIdentityRegistry.CountryUpdated(alice, 840);
        vm.prank(irAgent);
        ir.updateCountry(alice, 840);
        assertEq(ir.investorCountry(alice), 840);
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
        assertFalse(ir.isVerified(alice)); // new identity carries no claim yet
    }

    function test_DeleteIdentity() public {
        IIdentity id = _onboardInvestor(alice, 586);
        vm.expectEmit(true, true, false, false, address(ir));
        emit IIdentityRegistry.IdentityRemoved(alice, id);
        vm.prank(irAgent);
        ir.deleteIdentity(alice);
        assertFalse(ir.contains(alice));
        assertFalse(ir.isVerified(alice));
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

    function test_RegisterTwiceReverts() public {
        _onboardInvestor(alice, 586);
        IIdentity other = _newIdentity(alice);
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.AlreadyStored.selector, alice));
        ir.registerIdentity(alice, other, 586);
    }

    // ---------------------------------------------------------------- roles

    function test_RegistryAgentAndOwnerGates() public {
        IIdentity id = _newIdentity(alice);
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAgent.selector, stranger));
        ir.registerIdentity(alice, id, 1);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAgent.selector, stranger));
        ir.deleteIdentity(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotAgent.selector, stranger));
        ir.updateCountry(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.setClaimTopicsRegistry(address(topics));
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.setTrustedIssuersRegistry(address(issuers));
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.setIdentityRegistryStorage(address(irs));
        vm.expectRevert(abi.encodeWithSelector(OwnerAgentRoles.NotOwner.selector, stranger));
        ir.addAgent(stranger);
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
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, irAgent));
        irs.addIdentityToStorage(alice, id, 1);

        vm.prank(govOwner);
        irs.unbindIdentityRegistry(address(ir));
        vm.prank(irAgent);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, address(ir)));
        ir.registerIdentity(alice, id, 1);
    }

    function test_StorageSharedAcrossRegistries() public {
        _onboardInvestor(alice, 586);
        IdentityRegistry ir2 = new IdentityRegistry(govOwner, issuers, topics, irs);
        assertTrue(ir2.isVerified(alice)); // ADR 0016: one identity storage for every token
    }

    function test_StorageBinding() public {
        vm.startPrank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.RegistryAlreadyBound.selector, address(ir)));
        irs.bindIdentityRegistry(address(ir));
        vm.expectRevert(IdentityRegistryStorage.ZeroAddress.selector);
        irs.bindIdentityRegistry(address(0));
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.RegistryNotBound.selector, stranger));
        irs.unbindIdentityRegistry(stranger);
        vm.stopPrank();
        assertEq(irs.linkedIdentityRegistries().length, 1);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, stranger));
        irs.bindIdentityRegistry(stranger);
    }

    // ---------------------------------------------------------------- T1.3 topics registry

    function test_TopicsRegistry() public {
        assertEq(topics.getClaimTopics().length, 1);
        assertEq(topics.getClaimTopics()[0], KYC);
        vm.startPrank(govOwner);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.TopicAlreadyRequired.selector, KYC));
        topics.addClaimTopic(KYC);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.TopicNotRequired.selector, uint256(99)));
        topics.removeClaimTopic(99);
        for (uint256 i = 2; i <= 15; ++i) {
            topics.addClaimTopic(i);
        }
        vm.expectRevert(ClaimTopicsRegistry.TooManyTopics.selector);
        topics.addClaimTopic(16);
        vm.stopPrank();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.NotOwner.selector, stranger));
        topics.addClaimTopic(77);
    }

    // ---------------------------------------------------------------- T1.4 trusted issuers registry

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
        vm.expectRevert(TrustedIssuersRegistry.NoClaimTopics.selector);
        issuers.updateIssuerClaimTopics(kycIssuer, new uint256[](0));
        vm.expectRevert(TrustedIssuersRegistry.TooManyTopics.selector);
        issuers.updateIssuerClaimTopics(kycIssuer, new uint256[](16));
        vm.expectRevert(TrustedIssuersRegistry.ZeroAddress.selector);
        issuers.addTrustedIssuer(IClaimIssuer(address(0)), t);

        issuers.removeTrustedIssuer(kycIssuer);
        assertFalse(issuers.isTrustedIssuer(address(kycIssuer)));
        assertEq(issuers.getTrustedIssuers().length, 0);
        assertEq(issuers.getTrustedIssuersForClaimTopic(KYC + 1).length, 0);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.IssuerNotTrusted.selector, address(kycIssuer)));
        issuers.removeTrustedIssuer(kycIssuer);
        vm.stopPrank();
    }

    function test_TrustedIssuersOnlyOwner() public {
        uint256[] memory t = new uint256[](1);
        t[0] = KYC;
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TrustedIssuersRegistry.NotOwner.selector, stranger));
        issuers.addTrustedIssuer(IClaimIssuer(stranger), t);
    }
}
