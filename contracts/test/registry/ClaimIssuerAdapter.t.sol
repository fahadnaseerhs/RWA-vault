// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Identity} from "../../src/vendor/onchain-id/Identity.sol";
import {ClaimIssuer} from "../../src/vendor/onchain-id/ClaimIssuer.sol";
import {IIdentity} from "../../src/vendor/onchain-id/interface/IIdentity.sol";

/**
 * @title ClaimIssuerAdapterTest
 * @notice T1.2 — proves the vendored ClaimIssuer verifies ECDSA claims we produce
 *         with Foundry's deterministic test key (AC-T1-25, spec §5).
 *
 *         This is the first test that exercises the REAL vendored onchain-id code
 *         compiled at 0.8.26, not a mock. It proves:
 *         1. A claim signed by a registered CLAIM key is valid.
 *         2. A claim signed by an unregistered key is invalid.
 *         3. A revoked claim is invalid.
 *         4. The signing scheme matches what IdentityRegistry.isVerified will see.
 */
contract ClaimIssuerAdapterTest is Test {
    uint256 internal constant ISSUER_PK = 0xA11CE;
    uint256 internal constant RANDOM_PK = 0xDEAD;
    uint256 internal constant KYC_TOPIC = 1;
    uint256 internal constant ECDSA_SCHEME = 1;

    address internal issuerKeyAddr;
    address internal randomKeyAddr;
    ClaimIssuer internal issuer;
    Identity internal investorIdentity;

    address internal owner = makeAddr("owner (2-of-3 multisig)");
    address internal investor = makeAddr("investor");

    function setUp() public {
        issuerKeyAddr = vm.addr(ISSUER_PK);
        randomKeyAddr = vm.addr(RANDOM_PK);

        // Deploy the ClaimIssuer with the owner as management key.
        vm.startPrank(owner);
        issuer = new ClaimIssuer(owner);

        // Add the issuer's CLAIM signer key (purpose 3, ECDSA type 1).
        bytes32 claimKey = keccak256(abi.encode(issuerKeyAddr));
        issuer.addKey(claimKey, 3, 1);
        vm.stopPrank();

        // Deploy an investor identity with the investor as management key.
        investorIdentity = new Identity(investor, false);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _signClaim(uint256 pk, IIdentity identity, uint256 topic, bytes memory data)
        internal
        pure
        returns (bytes memory sig)
    {
        bytes32 dataHash = keccak256(abi.encode(identity, topic, data));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, prefixedHash);
        sig = abi.encodePacked(r, s, v);
    }

    // ------------------------------------------------------------------
    // AC-T1-25: vendored ClaimIssuer verifies an ECDSA claim we signed
    // ------------------------------------------------------------------

    function test_ValidClaimFromRegisteredKey() public view {
        bytes memory data = abi.encode("KYC verified");
        bytes memory sig = _signClaim(ISSUER_PK, IIdentity(address(investorIdentity)), KYC_TOPIC, data);

        bool valid = issuer.isClaimValid(IIdentity(address(investorIdentity)), KYC_TOPIC, sig, data);
        assertTrue(valid, "claim signed by registered CLAIM key must be valid");
    }

    function test_InvalidClaimFromUnregisteredKey() public view {
        bytes memory data = abi.encode("KYC verified");
        bytes memory sig = _signClaim(RANDOM_PK, IIdentity(address(investorIdentity)), KYC_TOPIC, data);

        bool valid = issuer.isClaimValid(IIdentity(address(investorIdentity)), KYC_TOPIC, sig, data);
        assertFalse(valid, "claim signed by unregistered key must be invalid");
    }

    function test_RevokedClaimIsInvalid() public {
        bytes memory data = abi.encode("KYC verified");
        bytes memory sig = _signClaim(ISSUER_PK, IIdentity(address(investorIdentity)), KYC_TOPIC, data);

        // Sanity: valid before revocation.
        assertTrue(
            issuer.isClaimValid(IIdentity(address(investorIdentity)), KYC_TOPIC, sig, data),
            "should be valid before revocation"
        );

        // Revoke the claim signature.
        vm.prank(owner);
        issuer.revokeClaimBySignature(sig);

        // Now invalid.
        bool valid = issuer.isClaimValid(IIdentity(address(investorIdentity)), KYC_TOPIC, sig, data);
        assertFalse(valid, "revoked claim must be invalid");
    }

    function test_WrongTopicInvalidatesClaim() public view {
        bytes memory data = abi.encode("KYC verified");
        uint256 wrongTopic = 42;
        bytes memory sig = _signClaim(ISSUER_PK, IIdentity(address(investorIdentity)), wrongTopic, data);

        // Verify against KYC_TOPIC — the signature was over wrongTopic, so ecrecover
        // will recover a different address and the key won't be found.
        bool valid = issuer.isClaimValid(IIdentity(address(investorIdentity)), KYC_TOPIC, sig, data);
        assertFalse(valid, "claim signed for wrong topic must be invalid when checked against KYC_TOPIC");
    }

    function test_WrongIdentityInvalidatesClaim() public {
        Identity otherIdentity = new Identity(makeAddr("other-investor"), false);
        bytes memory data = abi.encode("KYC verified");
        // Sign for investorIdentity but verify against otherIdentity.
        bytes memory sig = _signClaim(ISSUER_PK, IIdentity(address(investorIdentity)), KYC_TOPIC, data);

        bool valid = issuer.isClaimValid(IIdentity(address(otherIdentity)), KYC_TOPIC, sig, data);
        assertFalse(valid, "claim signed for a different identity must be invalid");
    }

    function test_EmptySignatureIsInvalid() public view {
        bytes memory data = abi.encode("KYC verified");
        bytes memory emptySig = "";

        bool valid = issuer.isClaimValid(IIdentity(address(investorIdentity)), KYC_TOPIC, emptySig, data);
        assertFalse(valid, "empty signature must be invalid");
    }

    // ------------------------------------------------------------------
    // AC-T1-15: end-to-end with real vendored Identity (isVerified path)
    // ------------------------------------------------------------------

    function test_EndToEndWithRealIdentityAndIssuer() public {
        // This test deploys real vendored Identity + ClaimIssuer, adds a claim
        // to the identity, and verifies the full isClaimValid flow that
        // IdentityRegistry.isVerified will call.

        bytes memory data = abi.encode("KYC verified for investor");
        bytes memory sig = _signClaim(ISSUER_PK, IIdentity(address(investorIdentity)), KYC_TOPIC, data);

        // The investor adds the claim to their identity.
        // addClaim requires CLAIM key (purpose 3) or self-call.
        // We'll use execute() from the management key to call addClaim.
        bytes memory addClaimData =
            abi.encodeCall(Identity.addClaim, (KYC_TOPIC, ECDSA_SCHEME, address(issuer), sig, data, ""));

        vm.prank(investor);
        investorIdentity.execute(address(investorIdentity), 0, addClaimData);

        // Verify the claim was stored.
        bytes32 claimId = keccak256(abi.encode(address(issuer), KYC_TOPIC));
        (uint256 topic,, address claimIssuer, bytes memory storedSig, bytes memory storedData,) =
            investorIdentity.getClaim(claimId);

        assertEq(topic, KYC_TOPIC, "stored claim topic must be KYC");
        assertEq(claimIssuer, address(issuer), "stored issuer must match");
        assertEq(keccak256(storedSig), keccak256(sig), "stored signature must match");
        assertEq(keccak256(storedData), keccak256(data), "stored data must match");

        // Now verify via isClaimValid — this is what IdentityRegistry calls.
        bool valid = issuer.isClaimValid(IIdentity(address(investorIdentity)), KYC_TOPIC, storedSig, storedData);
        assertTrue(valid, "end-to-end: claim stored on real Identity must validate via real ClaimIssuer");
    }
}
