// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployM3} from "../../script/DeployM3.s.sol";
import {VerifyWallet} from "../../script/VerifyWallet.s.sol";
import {KYC_TOPIC} from "../../src/registry/ClaimTopics.sol";
import {IAssetRegistry} from "../../src/registry/interfaces/IAssetRegistry.sol";

/**
 * @title DeployM3Test
 * @notice T5.1 spec §6: runs the deploy script in-process with anvil-style keys and checks
 *         the wiring again from outside, the smoke path, the squat check and the owner rule.
 */
contract DeployM3Test is Test {
    DeployM3 internal script;

    // Well-known anvil test keys (accounts 0-2). Local only; never used off anvil.
    uint256 internal constant OWNER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal constant AGENT_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant ISSUER_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    function setUp() public {
        vm.chainId(31337);
        vm.warp(1_800_000_000);
        vm.setEnv("M3_OWNER", vm.toString(vm.addr(OWNER_PK)));
        vm.setEnv("M3_OWNER_PK", vm.toString(OWNER_PK));
        vm.setEnv("M3_AGENT", vm.toString(vm.addr(AGENT_PK)));
        vm.setEnv("M3_AGENT_PK", vm.toString(AGENT_PK));
        vm.setEnv("M3_KYC_ISSUER_KEY", vm.toString(vm.addr(ISSUER_PK)));
        vm.setEnv("M3_KYC_ISSUER_PK", vm.toString(ISSUER_PK));
        vm.setEnv("M3_ASSET_REF", "gold-lot-001");
        vm.setEnv("M3_TOKEN_NAME", "QORA Gold Lot 001");
        vm.setEnv("M3_TOKEN_SYMBOL", "qXAU-001");
        vm.setEnv("M3_VALUATION_WINDOW", "86400");
        script = new DeployM3();
    }

    function _config() internal view returns (DeployM3.Config memory c) {
        c.owner = vm.addr(OWNER_PK);
        c.ownerPk = OWNER_PK;
        c.agent = vm.addr(AGENT_PK);
        c.agentPk = AGENT_PK;
        c.kycIssuerKey = vm.addr(ISSUER_PK);
        c.kycIssuerPk = ISSUER_PK;
        c.assetRef = "gold-lot-001";
        c.valuationWindow = 86400;
    }

    function test_RunWiresEverything() public {
        DeployM3.Deployment memory d = script.run();
        address owner = vm.addr(OWNER_PK);
        address agent = vm.addr(AGENT_PK);

        // §4 again, from outside.
        assertEq(address(d.token.identityRegistry()), address(d.identityRegistry));
        assertEq(address(d.token.compliance()), address(d.compliance));
        assertEq(d.compliance.getTokenBound(), address(d.token));
        assertTrue(d.compliance.isModuleBound(address(d.assetLiveModule)));
        uint256[] memory topics = d.claimTopicsRegistry.getClaimTopics();
        assertEq(topics.length, 1);
        assertEq(topics[0], KYC_TOPIC);
        assertTrue(d.trustedIssuersRegistry.hasClaimTopic(d.kycIssuer, KYC_TOPIC));
        assertEq(d.assetRegistry.attestationSource(), address(d.attestationSource));
        assertEq(d.assetRegistry.valuationWindowOf(bytes32(0)), 24 hours); // ADR 0018 default
        assertTrue(d.assetRegistry.isAgent(agent) && d.token.isAgent(agent) && d.identityRegistry.isAgent(agent));
        assertTrue(d.identityRegistry.isAgent(address(d.token)));
        assertTrue(d.attestationSource.isSubmitter(agent));
        assertEq(d.token.owner(), owner);
        assertFalse(d.token.paused());

        // §3: no asset bound at deploy, so a mint fails closed.
        assertEq(d.assetRegistry.assetOfToken(address(d.token)), bytes32(0));

        // The deployment file is checked against a real anvil run (AC-T5-1); tests run in
        // parallel and share it, so it is not read back here.
    }

    function test_SmokeOnboardsFixtureLot() public {
        DeployM3.Deployment memory d = script.smoke();
        bytes32 assetId = keccak256("gold-lot-001");
        assertEq(uint8(d.assetRegistry.stateOf(assetId)), uint8(IAssetRegistry.AssetState.LIVE));
        assertEq(d.token.totalSupply(), 999.9e18);
        assertLe(d.token.totalSupply(), d.assetRegistry.reserveOf(assetId));
        assertEq(d.assetRegistry.tokenOf(assetId), address(d.token));
    }

    function test_WiringCheckCatchesSquattedCompliance() public {
        DeployM3.Deployment memory d = script.run();
        address owner = vm.addr(OWNER_PK);
        address squatter = makeAddr("squatter");
        vm.prank(owner);
        d.compliance.unbindToken(address(d.token));
        vm.prank(squatter);
        d.compliance.bindToken(squatter);

        vm.expectRevert(abi.encodeWithSelector(DeployM3.WiringMismatch.selector, "compliance.token"));
        script.verifyWiring(d, _config());
    }

    function test_WiringCheckCatchesPausedToken() public {
        DeployM3.Deployment memory d = script.run();
        vm.prank(vm.addr(AGENT_PK));
        d.token.pause();
        vm.expectRevert(abi.encodeWithSelector(DeployM3.WiringMismatch.selector, "token.paused"));
        script.verifyWiring(d, _config());
    }

    function test_RejectsEoaOwnerOffAnvil() public {
        vm.chainId(421614);
        vm.expectRevert(abi.encodeWithSelector(DeployM3.OwnerMustBeContract.selector, vm.addr(OWNER_PK)));
        script.run();
    }

    function test_SmokeIsLocalOnly() public {
        vm.chainId(421614);
        vm.expectRevert(DeployM3.SmokeIsLocalOnly.selector);
        script.smoke();
    }

    // ---------------------------------------------------------------- VerifyWallet (spec §7)

    function _verifyKeys(uint256 walletPk) internal pure returns (VerifyWallet.Keys memory) {
        return VerifyWallet.Keys({walletPk: walletPk, kycIssuerPk: ISSUER_PK, agentPk: AGENT_PK});
    }

    function test_VerifyWalletMakesWalletVerified() public {
        DeployM3.Deployment memory d = script.run();
        (address wallet, uint256 pk) = makeAddrAndKey("fresh-wallet");
        assertFalse(d.identityRegistry.isVerified(wallet));
        new VerifyWallet().verify(wallet, 586, d.identityRegistry, d.kycIssuer, _verifyKeys(pk));
        assertTrue(d.identityRegistry.isVerified(wallet));
        assertEq(d.identityRegistry.investorCountry(wallet), 586);
    }

    function test_VerifyWalletDevnetOnly() public {
        DeployM3.Deployment memory d = script.run();
        (address wallet, uint256 pk) = makeAddrAndKey("fresh-wallet");
        VerifyWallet vw = new VerifyWallet();
        vm.chainId(421614);
        vm.expectRevert(VerifyWallet.VerifyWalletDevnetOnly.selector);
        vw.verify(wallet, 586, d.identityRegistry, d.kycIssuer, _verifyKeys(pk));
        vm.expectRevert(VerifyWallet.VerifyWalletDevnetOnly.selector);
        vw.run(wallet, 586);
    }

    function test_VerifyWalletRejectsWrongWalletKey() public {
        DeployM3.Deployment memory d = script.run();
        address wallet = makeAddr("fresh-wallet");
        (address other, uint256 otherPk) = makeAddrAndKey("other");
        VerifyWallet vw = new VerifyWallet();
        vm.expectRevert(abi.encodeWithSelector(VerifyWallet.KeyMismatch.selector, "wallet", wallet, other));
        vw.verify(wallet, 586, d.identityRegistry, d.kycIssuer, _verifyKeys(otherPk));
    }
}
