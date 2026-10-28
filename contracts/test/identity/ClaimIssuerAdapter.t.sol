// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IdentityFixtures} from "./IdentityFixtures.sol";
import {IIdentity} from "../../src/identity/interfaces/IIdentity.sol";

/**
 * @title ClaimIssuerAdapterTest
 * @notice T1.1 / T1.2: the vendored onchain-id v2.2.1 `ClaimIssuer` and `Identity` satisfy our
 *         `IClaimIssuer` / `IIdentity` interfaces with no adapter contract (T1 spec §1–§2).
 */
contract ClaimIssuerAdapterTest is IdentityFixtures {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        _deployIdentityLayer();
    }

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

    function test_ValidKycClaimIsValid() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signKycClaim(issuerSignerPk, id, "d");
        assertTrue(kycIssuer.isClaimValid(id, KYC, sig, "d"));
        assertFalse(kycIssuer.isClaimValid(id, KYC + 1, sig, "d"));
        assertFalse(kycIssuer.isClaimValid(id, KYC, sig, "other"));
    }

    function test_RevokedClaimIsInvalid() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signKycClaim(issuerSignerPk, id, "d");
        vm.prank(issuerManager);
        kycIssuer.revokeClaimBySignature(sig);
        assertTrue(kycIssuer.isClaimRevoked(sig));
        assertFalse(kycIssuer.isClaimValid(id, KYC, sig, "d"));
    }

    function test_ClaimSignedByNonClaimKeyIsInvalid() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signKycClaim(0xBAD, id, "d");
        assertFalse(kycIssuer.isClaimValid(id, KYC, sig, "d"));
    }

    function test_ClaimForOtherIdentityIsInvalid() public {
        IIdentity aliceId = _newIdentity(alice);
        IIdentity bobId = _newIdentity(bob);
        bytes memory sig = _signKycClaim(issuerSignerPk, aliceId, "d");
        assertFalse(kycIssuer.isClaimValid(bobId, KYC, sig, "d"));
    }

    function test_RemovedClaimKeyInvalidatesClaim() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signKycClaim(issuerSignerPk, id, "d");
        vm.prank(issuerManager);
        kycIssuer.removeKey(keccak256(abi.encode(issuerSigner)), CLAIM_PURPOSE);
        assertFalse(kycIssuer.isClaimValid(id, KYC, sig, "d"));
    }

    function test_RevokeOnlyManager() public {
        vm.prank(bob);
        vm.expectRevert("Permissions: Sender does not have management key");
        kycIssuer.revokeClaimBySignature("x");
    }

    function test_IdentityRefusesClaimWithBadSignature() public {
        IIdentity id = _newIdentity(alice);
        bytes memory sig = _signKycClaim(0xBAD, id, "d");
        vm.prank(alice);
        vm.expectRevert("invalid claim");
        id.addClaim(KYC, ECDSA_SCHEME, address(kycIssuer), sig, "d", "");
    }
}
