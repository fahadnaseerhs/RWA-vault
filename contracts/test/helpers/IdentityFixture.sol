// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IIdentity} from "../../src/identity/interfaces/IIdentity.sol";
import {IClaimIssuer} from "../../src/identity/interfaces/IClaimIssuer.sol";
import {ClaimTopicsRegistry} from "../../src/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../../src/registry/IdentityRegistryStorage.sol";
import {IdentityRegistry} from "../../src/registry/IdentityRegistry.sol";
import {IClaimTopicsRegistry} from "../../src/registry/interfaces/IClaimTopicsRegistry.sol";
import {ITrustedIssuersRegistry} from "../../src/registry/interfaces/ITrustedIssuersRegistry.sol";
import {IIdentityRegistryStorage} from "../../src/registry/interfaces/IIdentityRegistryStorage.sol";

/**
 * @title IdentityFixture
 * @notice Deploys the T1 identity layer against the vendored onchain-id v2.2.1 contracts
 *         (compiled with solc 0.8.17, deployed from their artifacts) and issues real
 *         ECDSA KYC claims, so tests exercise upstream claim verification, not a mock.
 */
abstract contract IdentityFixture is Test {
    uint256 internal constant KYC = 1; // MS1 single topic (Q02 = A); value is a deploy parameter
    uint256 internal constant ECDSA_SCHEME = 1;
    uint256 internal constant CLAIM_PURPOSE = 3;
    uint256 internal constant ECDSA_KEY_TYPE = 1;

    address internal govOwner = makeAddr("governance-multisig");
    address internal irAgent = makeAddr("tier1-agent");
    address internal issuerManager = makeAddr("kyc-issuer-manager");
    uint256 internal issuerSignerPk = 0xA11CE;
    address internal issuerSigner;

    ClaimTopicsRegistry internal topics;
    TrustedIssuersRegistry internal issuers;
    IdentityRegistryStorage internal irs;
    IdentityRegistry internal ir;
    IClaimIssuer internal kycIssuer;

    function _deployIdentityLayer() internal {
        issuerSigner = vm.addr(issuerSignerPk);
        topics = new ClaimTopicsRegistry(govOwner);
        issuers = new TrustedIssuersRegistry(govOwner);
        irs = new IdentityRegistryStorage(govOwner);
        ir = new IdentityRegistry(
            govOwner,
            ITrustedIssuersRegistry(address(issuers)),
            IClaimTopicsRegistry(address(topics)),
            IIdentityRegistryStorage(address(irs))
        );
        kycIssuer = _newClaimIssuer(issuerManager, issuerSigner);

        uint256[] memory t = new uint256[](1);
        t[0] = KYC;
        vm.startPrank(govOwner);
        topics.addClaimTopic(KYC);
        issuers.addTrustedIssuer(kycIssuer, t);
        irs.bindIdentityRegistry(address(ir));
        ir.addAgent(irAgent);
        vm.stopPrank();
    }

    /// @dev Upstream `Identity(initialManagementKey, isLibrary)`, deployed from its 0.8.17 artifact.
    function _newIdentity(address manager) internal returns (IIdentity) {
        return IIdentity(deployCode("Identity.sol:Identity", abi.encode(manager, false)));
    }

    /// @dev Upstream `ClaimIssuer(initialManagementKey)` with `signer` added as a CLAIM key.
    function _newClaimIssuer(address manager, address signer) internal returns (IClaimIssuer ci) {
        ci = IClaimIssuer(deployCode("ClaimIssuer.sol:ClaimIssuer", abi.encode(manager)));
        vm.prank(manager);
        ci.addKey(keccak256(abi.encode(signer)), CLAIM_PURPOSE, ECDSA_KEY_TYPE);
    }

    /// @dev The ONCHAINID claim signature: eth-signed `keccak256(abi.encode(identity, topic, data))`.
    function _signClaim(uint256 pk, IIdentity id, uint256 topic, bytes memory data)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 dataHash = keccak256(abi.encode(address(id), topic, data));
        bytes32 prefixed = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, prefixed);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Adds a claim from `issuer` (signed by `pk`) to the identity managed by `manager`.
    function _addClaim(address manager, IIdentity id, IClaimIssuer issuer, uint256 pk, uint256 topic)
        internal
        returns (bytes memory sig)
    {
        bytes memory data = abi.encode("kyc-passed", topic);
        sig = _signClaim(pk, id, topic, data);
        vm.prank(manager);
        id.addClaim(topic, ECDSA_SCHEME, address(issuer), sig, data, "");
    }

    /// @dev A wallet with its own identity, a valid KYC claim, registered in the identity registry.
    function _onboardInvestor(address wallet, uint16 country) internal returns (IIdentity id) {
        id = _newIdentity(wallet);
        _addClaim(wallet, id, kycIssuer, issuerSignerPk, KYC);
        vm.prank(irAgent);
        ir.registerIdentity(wallet, id, country);
    }
}
