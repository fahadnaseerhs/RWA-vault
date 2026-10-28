// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployM3} from "../../script/DeployM3.s.sol";
import {OnboardAsset} from "../../script/OnboardAsset.s.sol";
import {VerifyWallet} from "../../script/VerifyWallet.s.sol";
import {IAssetRegistry} from "../../src/registry/interfaces/IAssetRegistry.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";

/**
 * @title OnboardAssetTest
 * @notice T6.1a spec §4: the onboarding script run in-process against a real `DeployM3`
 *         deployment. The verified file that stage 1 (Node) writes is built here as JSON, so
 *         no Node runs inside forge. Clause 1 (the signature) is tested in Node.
 */
contract OnboardAssetTest is Test {
    // Well-known anvil test keys (accounts 0-2). Local only; never used off anvil.
    uint256 internal constant OWNER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal constant AGENT_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant ISSUER_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    uint256 internal constant NOW = 1_800_000_000;
    string internal constant ENVELOPE_NOTE =
        "This is the timestamp inside the signed envelope; editing the input file will not change it.";

    struct Lot {
        string slug;
        string description;
        uint256 grossWeight;
        uint256 fineness;
        string source;
        uint256 valuationTs;
        uint256 intendedSupply;
        uint256 attestations;
        string provider;
        string token;
    }

    struct Att {
        uint256 chainId;
        string slug;
        uint256 reserve;
        uint256 seq;
        uint256 valuationTs;
        bytes32 envelopeHash;
    }

    DeployM3.Deployment internal d;
    OnboardAsset internal script;
    VerifyWallet internal kyc;
    OnboardAsset.Deployed internal dep;
    OnboardAsset.Keys internal keys;
    address internal provider;
    uint256 internal providerPk;
    address internal agent;
    address internal owner;

    function setUp() public {
        vm.chainId(31337);
        vm.warp(NOW);
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

        d = new DeployM3().run();
        script = new OnboardAsset();
        kyc = new VerifyWallet();
        dep = _dep(d);
        keys = OnboardAsset.Keys({agentPk: AGENT_PK, ownerPk: OWNER_PK});
        agent = vm.addr(AGENT_PK);
        owner = vm.addr(OWNER_PK);
        (provider, providerPk) = makeAddrAndKey("provider");
        _kyc(d, provider, providerPk);
    }

    // ---------------------------------------------------------------- happy path and re-runs

    function test_OnboardHappyPathEndsLive() public {
        Lot memory l = _lot();
        bytes32 id = keccak256(bytes(l.slug));
        OnboardAsset.Outcome o = script.onboard(_input(l), _verified(_att(l)), dep, keys);

        assertEq(uint8(o), uint8(OnboardAsset.Outcome.Minted));
        assertEq(uint8(d.assetRegistry.stateOf(id)), uint8(IAssetRegistry.AssetState.LIVE));
        assertEq(d.token.totalSupply(), l.intendedSupply);
        assertLe(d.token.totalSupply(), d.assetRegistry.reserveOf(id));
        assertEq(d.token.balanceOf(provider), l.intendedSupply);
        assertEq(d.assetRegistry.tokenOf(id), address(d.token));
        assertEq(d.assetRegistry.lastSequenceOf(id), 1);
        assertEq(d.attestationSource.envelopeHashOf(id), _att(l).envelopeHash);
        assertEq(d.assetRegistry.metadataHashOf(id), script.metadataHash(script.parseInput(_input(l))));
    }

    function test_OnboardIsIdempotent() public {
        Lot memory l = _lot();
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
        OnboardAsset.Outcome o = script.onboard(_input(l), _verified(_att(l)), dep, keys);

        assertEq(uint8(o), uint8(OnboardAsset.Outcome.AlreadyLive));
        assertEq(d.token.totalSupply(), l.intendedSupply); // minted exactly once
        assertEq(d.assetRegistry.lastSequenceOf(keccak256(bytes(l.slug))), 1);
    }

    function test_OnboardResumesAfterAdmitBeforeMint() public {
        Lot memory l = _lot();
        Att memory a = _att(l);
        _registerBindAdmit(l, a);
        assertEq(d.token.totalSupply(), 0);

        OnboardAsset.Outcome o = script.onboard(_input(l), _verified(a), dep, keys);
        assertEq(uint8(o), uint8(OnboardAsset.Outcome.Minted));
        assertEq(d.token.totalSupply(), l.intendedSupply);
        assertEq(d.assetRegistry.lastSequenceOf(keccak256(bytes(l.slug))), 1); // no second admit
    }

    function test_OnboardWaitsForOwnerMultisig() public {
        Lot memory l = _lot();
        bytes32 id = keccak256(bytes(l.slug));
        OnboardAsset.Keys memory noOwner = OnboardAsset.Keys({agentPk: AGENT_PK, ownerPk: 0});

        OnboardAsset.Outcome o = script.onboard(_input(l), _verified(_att(l)), dep, noOwner);
        assertEq(uint8(o), uint8(OnboardAsset.Outcome.WaitingForOwner));
        assertEq(uint8(d.assetRegistry.stateOf(id)), uint8(IAssetRegistry.AssetState.PENDING));
        assertEq(d.assetRegistry.tokenOf(id), address(0));

        // The multisig executes; the same command then completes.
        vm.prank(owner);
        d.assetRegistry.setTokenFor(id, address(d.token));
        o = script.onboard(_input(l), _verified(_att(l)), dep, noOwner);
        assertEq(uint8(o), uint8(OnboardAsset.Outcome.Minted));
    }

    function test_OnboardSecondLotNoSolidityEdit() public {
        script.onboard(_input(_lot()), _verified(_att(_lot())), dep, keys);

        // A second lot is a second token (ADR 0016): deploy again, then change only the JSON.
        DeployM3.Deployment memory d2 = new DeployM3().run();
        _kyc(d2, provider, providerPk);
        Lot memory l2 = _lot();
        l2.slug = "gold-lot-003";
        l2.grossWeight = 500e18;
        l2.intendedSupply = 499.95e18;
        l2.token = vm.toString(address(d2.token));
        Att memory a2 = _att(l2);

        script.onboard(_input(l2), _verified(a2), _dep(d2), keys);
        assertTrue(d2.assetRegistry.isLive(keccak256("gold-lot-003")));
        assertEq(d2.token.totalSupply(), 499.95e18);
        assertEq(d.token.totalSupply(), 999.9e18);
    }

    // ---------------------------------------------------------------- admission clauses (AC-5)

    function test_OnboardRejectsStaleSequence() public {
        Lot memory l = _lot();
        bytes32 id = keccak256(bytes(l.slug));
        vm.prank(agent);
        d.assetRegistry.register(id, bytes32(0), l.slug);
        vm.prank(agent);
        d.attestationSource
            .submitAttestation(
                IReserveAttestationSource.ReserveAttestation(id, 999.9e18, 2, uint64(NOW - 60)), keccak256("other")
            );

        bytes memory reason = abi.encodeWithSelector(IAssetRegistry.StaleSequence.selector, uint64(1), uint64(2));
        string memory sentence =
            "This attestation (seq 1) is older than or equal to the last one accepted (seq 2). The source already holds a newer attestation (seq 2).";
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.AdmitRejected.selector, reason, sentence));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
    }

    function test_OnboardRejectsReserveTooLow() public {
        Lot memory l = _lot();
        Att memory a = _att(l);
        a.reserve = 900e18;

        bytes memory reason = abi.encodeWithSelector(IAssetRegistry.ReserveTooLow.selector, 900e18, 999.9e18);
        string memory sentence =
            "The attested reserve (900000000000000000000) is less than the supply you asked to mint (999900000000000000000).";
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.AdmitRejected.selector, reason, sentence));
        script.onboard(_input(l), _verified(a), dep, keys);
        assertEq(uint8(d.assetRegistry.stateOf(keccak256(bytes(l.slug)))), 0); // nothing sent
    }

    function test_OnboardRejectsValuationStale() public {
        Lot memory l = _lot();
        Att memory a = _att(l);
        a.valuationTs = NOW - 2 days;

        bytes memory reason =
            abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, uint64(NOW - 2 days), uint64(1 days));
        string memory sentence = string.concat("This valuation is 48 hours old; the limit is 24 hours. ", ENVELOPE_NOTE);
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.AdmitRejected.selector, reason, sentence));
        script.onboard(_input(l), _verified(a), dep, keys);
    }

    function test_OnboardRejectsValuationInFuture() public {
        Lot memory l = _lot();
        Att memory a = _att(l);
        a.valuationTs = NOW + 100;

        bytes memory reason =
            abi.encodeWithSelector(IAssetRegistry.ValuationInFuture.selector, uint64(NOW + 100), uint64(NOW));
        string memory sentence = string.concat(
            "This valuation is dated 100 seconds in the future (envelope valuationTs 1800000100, chain time 1800000000). ",
            ENVELOPE_NOTE
        );
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.AdmitRejected.selector, reason, sentence));
        script.onboard(_input(l), _verified(a), dep, keys);
    }

    function test_OnboardValuationStaleMessageNamesEnvelope() public {
        // The input file says "fresh"; the signed envelope is stale. The chain judges the envelope.
        Lot memory l = _lot();
        l.valuationTs = NOW - 60;
        Att memory a = _att(l);
        a.valuationTs = NOW - 25 hours;

        string memory sentence = script.describeAdmitError(
            abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, uint64(NOW - 25 hours), uint64(1 days))
        );
        assertEq(sentence, string.concat("This valuation is 25 hours old; the limit is 24 hours. ", ENVELOPE_NOTE));
        vm.expectRevert(
            abi.encodeWithSelector(
                OnboardAsset.AdmitRejected.selector,
                abi.encodeWithSelector(IAssetRegistry.ValuationStale.selector, uint64(NOW - 25 hours), uint64(1 days)),
                sentence
            )
        );
        script.onboard(_input(l), _verified(a), dep, keys);
    }

    function test_DescribeUnknownAdmitErrorSaysReportIt() public view {
        string memory s = script.describeAdmitError(hex"deadbeef");
        assertEq(s, "Admission reverted with 0xdeadbeef; unexpected; report it.");
    }

    // ---------------------------------------------------------------- pre-flight (AC-7, AC-20..22)

    function test_OnboardAbortsOnUnverifiedTreasury() public {
        Lot memory l = _lot();
        address stranger = makeAddr("never-kyc");
        l.provider = vm.toString(stranger);
        uint256 nonce = vm.getNonce(agent);

        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.ProviderNotVerified.selector, stranger));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
        assertEq(uint8(d.assetRegistry.stateOf(keccak256(bytes(l.slug)))), 0);
        assertEq(vm.getNonce(agent), nonce);
    }

    function test_OnboardRejectsBadChecksumAddress() public {
        Lot memory l = _lot();
        string memory bad = _flipFirstLetterCase(vm.toString(provider));
        l.provider = bad;
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.BadChecksumAddress.selector, "providerWallet", bad));
        script.parseInput(_input(l));

        // All-lowercase is accepted (no checksum claimed).
        l.provider = vm.toLowercase(vm.toString(provider));
        assertEq(script.parseInput(_input(l)).providerWallet, provider);
    }

    function test_OnboardPreflightNamesFailingCondition() public {
        Lot memory l = _lot();
        Att memory a = _att(l);
        _registerBindAdmit(l, a);
        vm.warp(NOW + 2 days); // the admitted valuation goes stale before the mint

        string memory condition = string.concat(
            "the admitted valuation is not fresh (valuationTs ",
            vm.toString(a.valuationTs),
            ", window 24 hours); submit a fresh attestation"
        );
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.MintPreflightFailed.selector, condition));
        script.onboard(_input(l), _verified(a), dep, keys);
    }

    function test_OnboardRefusesFixtureSourceOutsideTest() public {
        Lot memory l = _lot();
        vm.chainId(421614);
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.FixtureSourceOutsideTest.selector, l.source));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
    }

    function test_OnboardRejectsTwoAttestations() public {
        Lot memory l = _lot();
        l.attestations = 2;
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.TooManyAttestationsForMs1.selector, 2));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
    }

    function test_OnboardRejectsSupplyWeightMismatch() public {
        Lot memory l = _lot();
        l.intendedSupply = 1000e18;
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.SupplyWeightMismatch.selector, 1000e18, 999.9e18));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
    }

    function test_OnboardRejectsTokenMismatch() public {
        Lot memory l = _lot();
        address other = makeAddr("other-token");
        l.token = vm.toString(other);
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.TokenMismatch.selector, other, address(d.token)));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
    }

    function test_OnboardRejectsVerifiedFileForOtherAssetOrChain() public {
        Lot memory l = _lot();
        Att memory a = _att(l);
        a.slug = "gold-lot-999";
        vm.expectRevert(
            abi.encodeWithSelector(
                OnboardAsset.VerifiedFileForOtherAsset.selector, keccak256(bytes(l.slug)), keccak256("gold-lot-999")
            )
        );
        script.onboard(_input(l), _verified(a), dep, keys);

        a = _att(l);
        a.chainId = 1;
        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.AttestationForOtherChain.selector, 31337, 1));
        script.onboard(_input(l), _verified(a), dep, keys);
    }

    // ---------------------------------------------------------------- state branch

    function test_OnboardRefusesFrozenAsset() public {
        Lot memory l = _lot();
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
        vm.prank(agent);
        d.assetRegistry.freeze(keccak256(bytes(l.slug)), "custody check");

        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.AssetIsFrozen.selector, keccak256(bytes(l.slug))));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
    }

    function test_OnboardRefusesPartialSupply() public {
        Lot memory l = _lot();
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
        l.grossWeight = 2000e18;
        l.intendedSupply = 1999.8e18;

        vm.expectRevert(abi.encodeWithSelector(OnboardAsset.PartialSupply.selector, 999.9e18, 1999.8e18));
        script.onboard(_input(l), _verified(_att(l)), dep, keys);
    }

    function test_OnboardSourceHoldsSameEnvelopeIsSkipped() public {
        Lot memory l = _lot();
        Att memory a = _att(l);
        bytes32 id = keccak256(bytes(l.slug));
        vm.prank(agent);
        d.assetRegistry.register(id, bytes32(0), l.slug);
        vm.prank(agent);
        d.attestationSource
            .submitAttestation(
                IReserveAttestationSource.ReserveAttestation(id, a.reserve, uint64(a.seq), uint64(a.valuationTs)),
                a.envelopeHash
            );

        script.onboard(_input(l), _verified(a), dep, keys);
        assertTrue(d.assetRegistry.isLive(id));
    }

    // ---------------------------------------------------------------- metadataHash golden vector

    /// @dev The same value is asserted in `scripts/onboard/onboard.test.mjs` (viem) and lives in
    ///      `packages/types/src/__tests__/fixtures.ts` as `GOLD_LOT_001_METADATA_HASH`.
    function test_MetadataHashGoldenVector() public view {
        Lot memory l = Lot({
            slug: "gold-lot-001",
            description: "1kg kilobar, 999.9 fine, serial XAU-88213",
            grossWeight: 1000e18,
            fineness: 9999,
            source: "FIXTURE - synthetic, not a quote; per FINE gram",
            valuationTs: 1761523200,
            intendedSupply: 999.9e18,
            attestations: 1,
            provider: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
            token: "0x5FbDB2315678afecb367f032d93F642f64180aa3"
        });
        assertEq(
            script.metadataHash(script.parseInput(_input(l))),
            0x3312ef458e5205556ed418ffeb43dd9693817294e633bbc2f9f861b6a6deedd7
        );
    }

    // ---------------------------------------------------------------- helpers

    function _lot() internal view returns (Lot memory) {
        return Lot({
            slug: "gold-lot-002",
            description: "1kg kilobar, 999.9 fine, serial XAU-90001",
            grossWeight: 1000e18,
            fineness: 9999,
            source: "FIXTURE - synthetic, not a quote; per FINE gram",
            valuationTs: NOW - 600,
            intendedSupply: 999.9e18,
            attestations: 1,
            provider: vm.toString(provider),
            token: vm.toString(address(d.token))
        });
    }

    function _att(Lot memory l) internal pure returns (Att memory) {
        return Att({
            chainId: 31337,
            slug: l.slug,
            reserve: 999.9e18,
            seq: 1,
            valuationTs: NOW - 600,
            envelopeHash: keccak256(abi.encode("envelope", l.slug))
        });
    }

    function _input(Lot memory l) internal pure returns (string memory) {
        string memory atts = '{"path":"script/input/a.att.json","attestor":"custodian"}';
        for (uint256 i = 1; i < l.attestations; ++i) {
            atts = string.concat(atts, ',{"path":"script/input/b.att.json","attestor":"custodian"}');
        }
        return string.concat(
            string.concat(
                '{"assetId":"',
                l.slug,
                '","description":"',
                l.description,
                '","grossWeight":"',
                vm.toString(l.grossWeight),
                '","fineness":',
                vm.toString(l.fineness),
                ',"valuationBasis":{"source":"',
                l.source,
                '","currency":"USD","unitValue":"130000000000000000000","valuationTs":',
                vm.toString(l.valuationTs),
                "}"
            ),
            ',"custodianId":"custodian-brinks-dxb","intendedSupply":"',
            vm.toString(l.intendedSupply),
            '","attestations":[',
            atts,
            '],"providerWallet":"',
            l.provider,
            '","token":"',
            l.token,
            '"}'
        );
    }

    /// @dev The shape `scripts/onboard/run.mjs` writes to `.onboard/<slug>.verified.json`.
    function _verified(Att memory a) internal pure returns (string memory) {
        return string.concat(
            '{"chainId":',
            vm.toString(a.chainId),
            ',"assetRef":"',
            a.slug,
            '","assetId":"',
            vm.toString(keccak256(bytes(a.slug))),
            '","reserve":"',
            vm.toString(a.reserve),
            '","seq":',
            vm.toString(a.seq),
            ',"valuationTs":',
            vm.toString(a.valuationTs),
            ',"envelopeHash":"',
            vm.toString(a.envelopeHash),
            '","verifiedAt":"2027-01-15T08:00:00.000Z","verifier":"pq-core ml-dsa-65 0.0.1"}'
        );
    }

    function _dep(DeployM3.Deployment memory x) internal pure returns (OnboardAsset.Deployed memory) {
        return OnboardAsset.Deployed({
            identityRegistry: x.identityRegistry,
            assetRegistry: x.assetRegistry,
            attestationSource: x.attestationSource,
            token: x.token
        });
    }

    function _kyc(DeployM3.Deployment memory x, address wallet, uint256 pk) internal {
        kyc.verify(
            wallet,
            586,
            x.identityRegistry,
            x.kycIssuer,
            VerifyWallet.Keys({walletPk: pk, kycIssuerPk: ISSUER_PK, agentPk: AGENT_PK})
        );
    }

    /// @dev What an earlier run that stopped after admit, before mint, leaves on chain.
    function _registerBindAdmit(Lot memory l, Att memory a) internal {
        bytes32 id = keccak256(bytes(l.slug));
        vm.startPrank(agent);
        d.assetRegistry.register(id, bytes32(0), l.slug);
        d.attestationSource
            .submitAttestation(
                IReserveAttestationSource.ReserveAttestation(id, a.reserve, uint64(a.seq), uint64(a.valuationTs)),
                a.envelopeHash
            );
        vm.stopPrank();
        vm.prank(owner);
        d.assetRegistry.setTokenFor(id, address(d.token));
        vm.prank(agent);
        d.assetRegistry.admit(id, l.intendedSupply);
    }

    function _flipFirstLetterCase(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        for (uint256 i = 2; i < b.length; ++i) {
            if (b[i] >= "a" && b[i] <= "f") {
                b[i] = bytes1(uint8(b[i]) - 32);
                return string(b);
            }
            if (b[i] >= "A" && b[i] <= "F") {
                b[i] = bytes1(uint8(b[i]) + 32);
                return string(b);
            }
        }
        revert("no letter to flip");
    }
}
