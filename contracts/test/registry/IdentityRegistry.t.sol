// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IClaimIssuer} from "../../src/vendor/onchain-id/interface/IClaimIssuer.sol";
import {IIdentity} from "../../src/vendor/onchain-id/interface/IIdentity.sol";
import {IIdentityRegistry} from "../../src/registry/interfaces/IIdentityRegistry.sol";
import {IIdentityRegistryStorage} from "../../src/registry/interfaces/IIdentityRegistryStorage.sol";
import {ClaimTopicsRegistry} from "../../src/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../../src/registry/IdentityRegistryStorage.sol";
import {IdentityRegistry} from "../../src/registry/IdentityRegistry.sol";
import {MockIdentity} from "../mocks/MockIdentity.sol";
import {MockClaimIssuer} from "../mocks/MockClaimIssuer.sol";

/**
 * @title IdentityRegistryTest
 * @notice T1.5 unit tests and T1.6 test matrix.
 *
 *         The test matrix from spec §14 (seven cases a plausible implementation passes):
 *         1. Claim from issuer trusted for a DIFFERENT topic (AC-T1-7)
 *         2. Empty topic set → false (AC-T1-6)
 *         3. Identity with NO claims at all (AC-T1-32)
 *         4. updateIdentity, then verify (AC-T1-9)
 *         5. updateCountry does NOT affect isVerified (AC-T1-10)
 *         6. Issuer REMOVED after claim was issued (AC-T1-34)
 *         7. Topic ADDED after wallet was verified (AC-T1-35)
 *
 *         Three distinct addresses asserted (AC-T1-11): issuer ≠ agent ≠ submitter.
 */
contract IdentityRegistryTest is Test {
    // ── Roles (AC-T1-11: three distinct addresses) ───────────────────────────
    address internal owner = makeAddr("owner (2-of-3 multisig)");
    address internal agentAddr = makeAddr("agent (Tier 1 service key)");
    address internal submitter = makeAddr("submitter (attestation)");
    address internal stranger = makeAddr("stranger");
    address internal walletAlice = makeAddr("Alice wallet");
    address internal walletBob = makeAddr("Bob wallet");

    uint256 internal constant KYC_TOPIC = 1;
    uint256 internal constant AML_TOPIC = 7;
    uint16 internal constant COUNTRY_PK = 586; // Pakistan

    // ── Contracts ────────────────────────────────────────────────────────────
    ClaimTopicsRegistry internal topicsReg;
    TrustedIssuersRegistry internal issuersReg;
    IdentityRegistryStorage internal idStorage;
    IdentityRegistry internal registry;

    MockIdentity internal identityAlice;
    MockIdentity internal identityBob;
    MockClaimIssuer internal issuer;

    function setUp() public {
        // AC-T1-11: assert the three distinct addresses before anything else.
        assertTrue(owner != agentAddr, "owner != agent");
        assertTrue(agentAddr != submitter, "agent != submitter");
        assertTrue(owner != submitter, "owner != submitter");

        // Deploy registries.
        topicsReg = new ClaimTopicsRegistry(owner);
        issuersReg = new TrustedIssuersRegistry(owner);
        idStorage = new IdentityRegistryStorage(owner);
        registry = new IdentityRegistry(
            owner,
            agentAddr,
            IIdentityRegistryStorage(address(idStorage)),
            ClaimTopicsRegistry(address(topicsReg)),
            TrustedIssuersRegistry(address(issuersReg))
        );

        // Bind registry to storage (owner-only on storage).
        vm.prank(owner);
        idStorage.bindIdentityRegistry(address(registry));

        // Deploy mock identity and issuer contracts.
        identityAlice = new MockIdentity();
        identityBob = new MockIdentity();
        issuer = new MockClaimIssuer();

        // Trust the issuer for KYC.
        uint256[] memory kycTopics = new uint256[](1);
        kycTopics[0] = KYC_TOPIC;
        vm.prank(owner);
        issuersReg.addTrustedIssuer(IClaimIssuer(address(issuer)), kycTopics);

        // Give Alice a KYC claim from the trusted issuer.
        identityAlice.mockAddClaim(KYC_TOPIC, 1, address(issuer), "alice-sig", "alice-data", "");

        // Register Alice.
        vm.prank(agentAddr);
        registry.registerIdentity(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
    }

    // ------------------------------------------------------------------
    // Constructor and setup
    // ------------------------------------------------------------------

    function test_ConstructorSetsOwner() public view {
        assertEq(registry.owner(), owner);
    }

    function test_ConstructorSetsAgent() public view {
        assertEq(registry.agent(), agentAddr);
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.InvalidOwner.selector, address(0)));
        new IdentityRegistry(
            address(0),
            agentAddr,
            IIdentityRegistryStorage(address(idStorage)),
            ClaimTopicsRegistry(address(topicsReg)),
            TrustedIssuersRegistry(address(issuersReg))
        );
    }

    function test_ConstructorRejectsZeroAgent() public {
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.InvalidAgent.selector, address(0)));
        new IdentityRegistry(
            owner,
            address(0),
            IIdentityRegistryStorage(address(idStorage)),
            ClaimTopicsRegistry(address(topicsReg)),
            TrustedIssuersRegistry(address(issuersReg))
        );
    }

    // ------------------------------------------------------------------
    // AC-T1-12: no initializers, no storage gaps, no proxy
    // ------------------------------------------------------------------

    // This is verified by inspection: no `initialize` function, no `uint256[50] __gap`,
    // and the constructor wires everything. It compiles, which is the test.

    // ------------------------------------------------------------------
    // Registration (agent operations)
    // ------------------------------------------------------------------

    function test_RegisterIdentityEmitsEvent() public {
        MockIdentity id = new MockIdentity();
        vm.prank(agentAddr);
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistry.IdentityRegistered(walletBob, IIdentity(address(id)));
        registry.registerIdentity(walletBob, IIdentity(address(id)), COUNTRY_PK);
    }

    function test_RegisterIdentityReadBack() public {
        MockIdentity id = new MockIdentity();
        vm.prank(agentAddr);
        registry.registerIdentity(walletBob, IIdentity(address(id)), COUNTRY_PK);
        assertTrue(registry.contains(walletBob), "wallet should be registered");
        assertEq(address(registry.identity(walletBob)), address(id), "identity should match");
        assertEq(registry.investorCountry(walletBob), COUNTRY_PK, "country should match");
    }

    /// AC-T1-14: registerIdentity with no-code identity reverts.
    function test_RegisterWithNoCodeIdentityReverts() public {
        address noCode = makeAddr("no-code identity");
        vm.prank(agentAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.IdentityHasNoCode.selector, noCode));
        registry.registerIdentity(walletBob, IIdentity(noCode), COUNTRY_PK);
    }

    function test_RegisterDuplicateWalletReverts() public {
        // Alice is already registered in setUp.
        MockIdentity id = new MockIdentity();
        vm.prank(agentAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityAlreadyStored.selector, walletAlice));
        registry.registerIdentity(walletAlice, IIdentity(address(id)), COUNTRY_PK);
    }

    // ------------------------------------------------------------------
    // deleteIdentity
    // ------------------------------------------------------------------

    function test_DeleteIdentity() public {
        vm.prank(agentAddr);
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistry.IdentityRemoved(walletAlice, IIdentity(address(identityAlice)));
        registry.deleteIdentity(walletAlice);
        assertFalse(registry.contains(walletAlice), "wallet should be deregistered");
    }

    /// AC-T1-31: deleteIdentity on an unregistered wallet reverts.
    function test_DeleteUnregisteredWalletReverts() public {
        vm.prank(agentAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.IdentityNotRegistered.selector, walletBob));
        registry.deleteIdentity(walletBob);
    }

    // ------------------------------------------------------------------
    // updateIdentity (AC-T1-9)
    // ------------------------------------------------------------------

    function test_UpdateIdentityEmitsEvent() public {
        MockIdentity newId = new MockIdentity();
        vm.prank(agentAddr);
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistry.IdentityUpdated(IIdentity(address(identityAlice)), IIdentity(address(newId)));
        registry.updateIdentity(walletAlice, IIdentity(address(newId)));
    }

    function test_UpdateIdentityChangesStoredIdentity() public {
        MockIdentity newId = new MockIdentity();
        vm.prank(agentAddr);
        registry.updateIdentity(walletAlice, IIdentity(address(newId)));
        assertEq(address(registry.identity(walletAlice)), address(newId), "identity should be updated");
    }

    function test_UpdateIdentityWithNoCodeReverts() public {
        address noCode = makeAddr("no-code");
        vm.prank(agentAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.IdentityHasNoCode.selector, noCode));
        registry.updateIdentity(walletAlice, IIdentity(noCode));
    }

    function test_UpdateUnregisteredWalletReverts() public {
        MockIdentity id = new MockIdentity();
        vm.prank(agentAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.IdentityNotRegistered.selector, walletBob));
        registry.updateIdentity(walletBob, IIdentity(address(id)));
    }

    // ------------------------------------------------------------------
    // updateCountry (AC-T1-10)
    // ------------------------------------------------------------------

    function test_UpdateCountryEmitsEvent() public {
        vm.prank(agentAddr);
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistry.CountryUpdated(walletAlice, 840);
        registry.updateCountry(walletAlice, 840);
    }

    function test_UpdateCountryChangesCountry() public {
        vm.prank(agentAddr);
        registry.updateCountry(walletAlice, 840);
        assertEq(registry.investorCountry(walletAlice), 840, "country should be 840 (US)");
    }

    function test_UpdateCountryOfUnregisteredReverts() public {
        vm.prank(agentAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.IdentityNotRegistered.selector, walletBob));
        registry.updateCountry(walletBob, 840);
    }

    // ------------------------------------------------------------------
    // batchRegisterIdentity (AC-T1-30)
    // ------------------------------------------------------------------

    function test_BatchRegisterIdentity() public {
        MockIdentity id1 = new MockIdentity();
        MockIdentity id2 = new MockIdentity();
        address w1 = makeAddr("batch-1");
        address w2 = makeAddr("batch-2");

        address[] memory wallets = new address[](2);
        wallets[0] = w1;
        wallets[1] = w2;
        IIdentity[] memory ids = new IIdentity[](2);
        ids[0] = IIdentity(address(id1));
        ids[1] = IIdentity(address(id2));
        uint16[] memory countries = new uint16[](2);
        countries[0] = COUNTRY_PK;
        countries[1] = 840;

        vm.prank(agentAddr);
        registry.batchRegisterIdentity(wallets, ids, countries);

        assertTrue(registry.contains(w1), "w1 should be registered");
        assertTrue(registry.contains(w2), "w2 should be registered");
    }

    /// AC-T1-30: batch is all-or-nothing.
    function test_BatchRevertsEntirelyOnDuplicate() public {
        MockIdentity id1 = new MockIdentity();
        MockIdentity id2 = new MockIdentity();
        address w1 = walletAlice; // already registered → will fail
        address w2 = makeAddr("batch-2");

        address[] memory wallets = new address[](2);
        wallets[0] = w1;
        wallets[1] = w2;
        IIdentity[] memory ids = new IIdentity[](2);
        ids[0] = IIdentity(address(id1));
        ids[1] = IIdentity(address(id2));
        uint16[] memory countries = new uint16[](2);
        countries[0] = COUNTRY_PK;
        countries[1] = 840;

        vm.prank(agentAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityAlreadyStored.selector, walletAlice));
        registry.batchRegisterIdentity(wallets, ids, countries);

        // w2 should NOT be registered (entire batch reverted).
        assertFalse(registry.contains(w2), "batch should have reverted entirely");
    }

    function test_BatchArrayLengthMismatchReverts() public {
        address[] memory wallets = new address[](1);
        wallets[0] = makeAddr("w");
        IIdentity[] memory ids = new IIdentity[](2);
        uint16[] memory countries = new uint16[](1);

        vm.prank(agentAddr);
        vm.expectRevert(IdentityRegistry.ArrayLengthMismatch.selector);
        registry.batchRegisterIdentity(wallets, ids, countries);
    }

    // ------------------------------------------------------------------
    // Owner operations (registry setters, setAgent)
    // ------------------------------------------------------------------

    function test_SetAgent() public {
        address newAgent = makeAddr("new-agent");
        vm.prank(owner);
        registry.setAgent(newAgent);
        assertEq(registry.agent(), newAgent);
    }

    function test_SetAgentRejectsZero() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.InvalidAgent.selector, address(0)));
        registry.setAgent(address(0));
    }

    function test_SetIdentityRegistryStorage() public {
        IdentityRegistryStorage newStorage = new IdentityRegistryStorage(owner);
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IIdentityRegistry.IdentityStorageSet(address(newStorage));
        registry.setIdentityRegistryStorage(address(newStorage));
        assertEq(address(registry.identityStorage()), address(newStorage));
    }

    function test_SetClaimTopicsRegistry() public {
        ClaimTopicsRegistry newTopics = new ClaimTopicsRegistry(owner);
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IIdentityRegistry.ClaimTopicsRegistrySet(address(newTopics));
        registry.setClaimTopicsRegistry(address(newTopics));
        assertEq(address(registry.topicsRegistry()), address(newTopics));
    }

    function test_SetTrustedIssuersRegistry() public {
        TrustedIssuersRegistry newIssuers = new TrustedIssuersRegistry(owner);
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IIdentityRegistry.TrustedIssuersRegistrySet(address(newIssuers));
        registry.setTrustedIssuersRegistry(address(newIssuers));
        assertEq(address(registry.issuersRegistry()), address(newIssuers));
    }

    // ------------------------------------------------------------------
    // Access control (T1 spec §6)
    // ------------------------------------------------------------------

    function test_OnlyAgentCanRegister() public {
        MockIdentity id = new MockIdentity();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotAuthorisedAgent.selector, stranger));
        registry.registerIdentity(walletBob, IIdentity(address(id)), COUNTRY_PK);
    }

    function test_OnlyAgentCanDelete() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotAuthorisedAgent.selector, stranger));
        registry.deleteIdentity(walletAlice);
    }

    function test_OnlyAgentCanUpdateIdentity() public {
        MockIdentity id = new MockIdentity();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotAuthorisedAgent.selector, stranger));
        registry.updateIdentity(walletAlice, IIdentity(address(id)));
    }

    function test_OnlyAgentCanUpdateCountry() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotAuthorisedAgent.selector, stranger));
        registry.updateCountry(walletAlice, 840);
    }

    function test_OnlyOwnerCanSetRegistryStorage() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotOwner.selector, stranger));
        registry.setIdentityRegistryStorage(address(1));
    }

    function test_OnlyOwnerCanSetTopicsRegistry() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotOwner.selector, stranger));
        registry.setClaimTopicsRegistry(address(1));
    }

    function test_OnlyOwnerCanSetIssuersRegistry() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotOwner.selector, stranger));
        registry.setTrustedIssuersRegistry(address(1));
    }

    function test_OnlyOwnerCanSetAgent() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.NotOwner.selector, stranger));
        registry.setAgent(stranger);
    }

    // ==================================================================
    // isVerified — the heart of T1 (§7 algorithm)
    // ==================================================================

    /// Happy path: Alice has a valid KYC claim from a trusted issuer.
    function test_IsVerifiedHappyPath() public view {
        assertTrue(registry.isVerified(walletAlice), "Alice should be verified");
    }

    /// Unregistered wallet → false.
    function test_UnregisteredWalletNotVerified() public view {
        assertFalse(registry.isVerified(walletBob), "unregistered wallet should not be verified");
    }

    // ------------------------------------------------------------------
    // T1.6 Case 1 — AC-T1-7: claim from issuer trusted for a DIFFERENT topic
    // ------------------------------------------------------------------

    /// The most likely defect in all of T1 (spec §7, §12). An issuer trusted for
    /// AML but not KYC should NOT pass KYC verification, even though it IS trusted.
    function test_ClaimFromIssuerTrustedForAnotherTopicDoesNotVerify() public {
        // Deploy a second issuer trusted only for AML.
        MockClaimIssuer amlIssuer = new MockClaimIssuer();
        uint256[] memory amlTopics = new uint256[](1);
        amlTopics[0] = AML_TOPIC;
        vm.prank(owner);
        issuersReg.addTrustedIssuer(IClaimIssuer(address(amlIssuer)), amlTopics);

        // Deploy a new identity with a KYC claim from the AML-only issuer.
        MockIdentity badId = new MockIdentity();
        badId.mockAddClaim(KYC_TOPIC, 1, address(amlIssuer), "bad-sig", "bad-data", "");

        vm.prank(agentAddr);
        registry.registerIdentity(walletBob, IIdentity(address(badId)), COUNTRY_PK);

        assertFalse(registry.isVerified(walletBob), "claim from issuer trusted for AML only must NOT satisfy KYC");
    }

    // ------------------------------------------------------------------
    // T1.6 Case 2 — AC-T1-6: empty topic set → false
    // ------------------------------------------------------------------

    /// Defence-in-depth: isVerified returns false if the topic set is empty, even though
    /// ClaimTopicsRegistry's guards make it unreachable. Tested with a mock that bypasses
    /// the guard (per spec: "tested directly, by constructing that state in a mock").
    function test_EmptyTopicSetReturnsFalse() public {
        // Create a mock topics registry that returns empty.
        MockEmptyTopicsRegistry emptyTopics = new MockEmptyTopicsRegistry();
        vm.prank(owner);
        registry.setClaimTopicsRegistry(address(emptyTopics));

        // Alice is registered and has a valid claim — but no topics means vacuously...
        // The correct answer is FALSE (fail-closed), not TRUE (vacuously true).
        assertFalse(
            registry.isVerified(walletAlice), "empty topic set must return false (fail-closed, not vacuously true)"
        );
    }

    // ------------------------------------------------------------------
    // T1.6 Case 3 — AC-T1-32: identity with no claims at all
    // ------------------------------------------------------------------

    /// A different path from "no identity": the identity exists but has zero claims
    /// for the required topic. A zero-length loop returns the wrong default if the
    /// satisfied flag is initialised to true.
    function test_IdentityWithNoClaimsNotVerified() public {
        // Register Bob with a blank identity (no claims).
        MockIdentity blankId = new MockIdentity();
        vm.prank(agentAddr);
        registry.registerIdentity(walletBob, IIdentity(address(blankId)), COUNTRY_PK);

        assertFalse(registry.isVerified(walletBob), "identity with no claims should not be verified");
    }

    // ------------------------------------------------------------------
    // T1.6 Case 4 — AC-T1-9: updateIdentity moves verification
    // ------------------------------------------------------------------

    /// The old identity's claims stop counting immediately after updateIdentity.
    function test_UpdateIdentityMovesVerification() public {
        // Alice is verified with her current identity.
        assertTrue(registry.isVerified(walletAlice), "Alice should start verified");

        // Update to a new identity with NO claims.
        MockIdentity newId = new MockIdentity();
        vm.prank(agentAddr);
        registry.updateIdentity(walletAlice, IIdentity(address(newId)));

        // Old identity's claims no longer count.
        assertFalse(registry.isVerified(walletAlice), "old identity's claims must stop counting after updateIdentity");

        // Add a KYC claim to the new identity.
        newId.mockAddClaim(KYC_TOPIC, 1, address(issuer), "new-alice-sig", "new-alice-data", "");

        // Now verified again.
        assertTrue(registry.isVerified(walletAlice), "new identity with valid claim should be verified");
    }

    // ------------------------------------------------------------------
    // T1.6 Case 5 — AC-T1-10: updateCountry does NOT affect isVerified
    // ------------------------------------------------------------------

    /// Q02 = A: no country rule. Changing the country must not change verification.
    function test_UpdateCountryDoesNotAffectVerification() public {
        assertTrue(registry.isVerified(walletAlice), "Alice should be verified before country change");
        vm.prank(agentAddr);
        registry.updateCountry(walletAlice, 840); // US
        assertTrue(
            registry.isVerified(walletAlice), "changing country must not affect isVerified (Q02=A: no country rule)"
        );
    }

    // ------------------------------------------------------------------
    // T1.6 Case 6 — AC-T1-34: issuer removed after claim was issued
    // ------------------------------------------------------------------

    /// A claim from a since-removed issuer does not verify. The claim is intact;
    /// the authority is gone.
    function test_RemovedIssuerClaimDoesNotVerify() public {
        assertTrue(registry.isVerified(walletAlice), "Alice should be verified before issuer removal");

        // Remove the trusted issuer.
        vm.prank(owner);
        issuersReg.removeTrustedIssuer(IClaimIssuer(address(issuer)));

        assertFalse(registry.isVerified(walletAlice), "claim from a removed issuer must not verify");
    }

    // ------------------------------------------------------------------
    // T1.6 Case 7 — AC-T1-35: topic added after wallet was verified
    // ------------------------------------------------------------------

    /// Adding a required topic retroactively unverifies everyone who lacks a claim
    /// for it. This is correct behaviour and a live operational hazard: an owner
    /// adding a topic can freeze every holder's transfers without touching the token.
    function test_AddedTopicUnverifiesPreviouslyVerifiedWallet() public {
        assertTrue(registry.isVerified(walletAlice), "Alice should be verified before topic addition");

        // Owner adds AML topic (topic 7).
        vm.prank(owner);
        topicsReg.addClaimTopic(AML_TOPIC);

        // Alice has KYC but no AML claim → no longer verified.
        assertFalse(registry.isVerified(walletAlice), "adding a topic must unverify wallets lacking that topic's claim");

        // Give Alice an AML claim and re-check.
        identityAlice.mockAddClaim(AML_TOPIC, 1, address(issuer), "alice-aml-sig", "alice-aml-data", "");
        // But the issuer is only trusted for KYC, not AML. So still not verified.
        assertFalse(registry.isVerified(walletAlice), "AML claim from KYC-only issuer must not satisfy AML topic");

        // Trust the issuer for AML too.
        uint256[] memory bothTopics = new uint256[](2);
        bothTopics[0] = KYC_TOPIC;
        bothTopics[1] = AML_TOPIC;
        vm.prank(owner);
        issuersReg.updateIssuerClaimTopics(IClaimIssuer(address(issuer)), bothTopics);

        // Now verified.
        assertTrue(
            registry.isVerified(walletAlice), "with both claims and issuer trusted for both topics, should verify"
        );
    }

    // ------------------------------------------------------------------
    // Additional isVerified edge cases
    // ------------------------------------------------------------------

    /// A revoked claim does not verify (AC-T1-8).
    function test_RevokedClaimDoesNotVerify() public {
        assertTrue(registry.isVerified(walletAlice), "Alice should start verified");

        // Revoke the claim signature.
        issuer.revokeClaimBySignature("alice-sig");

        assertFalse(registry.isVerified(walletAlice), "revoked claim must not verify");
    }

    /// A claim from an entirely wrong issuer does not verify (AC-T1-8).
    function test_WrongIssuerClaimDoesNotVerify() public {
        // Deploy an untrusted issuer.
        MockClaimIssuer untrusted = new MockClaimIssuer();
        MockIdentity badId = new MockIdentity();
        badId.mockAddClaim(KYC_TOPIC, 1, address(untrusted), "bad-sig", "bad-data", "");

        vm.prank(agentAddr);
        registry.registerIdentity(walletBob, IIdentity(address(badId)), COUNTRY_PK);

        assertFalse(registry.isVerified(walletBob), "claim from an untrusted issuer must not verify");
    }

    // ------------------------------------------------------------------
    // AC-T1-33: storage bound to two registries serves both
    // ------------------------------------------------------------------

    /// The ADR 0016 sharing property: a single storage serves two Identity Registries.
    function test_StorageBoundToTwoRegistriesServesBoth() public {
        // Deploy a second IdentityRegistry pointing at the same storage.
        address agent2 = makeAddr("agent-2");
        IdentityRegistry registry2 = new IdentityRegistry(
            owner,
            agent2,
            IIdentityRegistryStorage(address(idStorage)),
            ClaimTopicsRegistry(address(topicsReg)),
            TrustedIssuersRegistry(address(issuersReg))
        );
        vm.prank(owner);
        idStorage.bindIdentityRegistry(address(registry2));

        // Alice was registered via registry. Both should see her.
        assertTrue(registry.contains(walletAlice), "registry 1 should see Alice");
        assertTrue(registry2.contains(walletAlice), "registry 2 should see Alice");
        assertTrue(registry2.isVerified(walletAlice), "registry 2 should verify Alice");

        // Register Bob via registry2.
        MockIdentity id2 = new MockIdentity();
        id2.mockAddClaim(KYC_TOPIC, 1, address(issuer), "bob-sig", "bob-data", "");
        vm.prank(agent2);
        registry2.registerIdentity(walletBob, IIdentity(address(id2)), COUNTRY_PK);

        // Both registries should see Bob.
        assertTrue(registry.contains(walletBob), "registry 1 should see Bob");
        assertTrue(registry2.contains(walletBob), "registry 2 should see Bob");
    }
}

// ==================================================================
// Test helpers
// ==================================================================

/// @dev A mock ClaimTopicsRegistry that returns an empty topic set, to test AC-T1-6.
/// Cannot be reached through the real ClaimTopicsRegistry (its guards prevent it),
/// so we construct the state directly.
contract MockEmptyTopicsRegistry {
    function getClaimTopics() external pure returns (uint256[] memory) {
        return new uint256[](0);
    }

    fallback() external payable {}
    receive() external payable {}
}
