// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IClaimIssuer} from "../src/identity/interfaces/IClaimIssuer.sol";
import {IIdentity} from "../src/identity/interfaces/IIdentity.sol";
import {KYC_TOPIC} from "../src/registry/ClaimTopics.sol";
import {ClaimTopicsRegistry} from "../src/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../src/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../src/registry/IdentityRegistryStorage.sol";
import {IdentityRegistry} from "../src/registry/IdentityRegistry.sol";
import {AssetRegistry} from "../src/registry/AssetRegistry.sol";
import {CustodianAttestationSource} from "../src/registry/CustodianAttestationSource.sol";
import {IAssetRegistry} from "../src/registry/interfaces/IAssetRegistry.sol";
import {IReserveAttestationSource} from "../src/registry/interfaces/IReserveAttestationSource.sol";
import {ITrustedIssuersRegistry} from "../src/registry/interfaces/ITrustedIssuersRegistry.sol";
import {IClaimTopicsRegistry} from "../src/registry/interfaces/IClaimTopicsRegistry.sol";
import {IIdentityRegistryStorage} from "../src/registry/interfaces/IIdentityRegistryStorage.sol";
import {ModularCompliance} from "../src/compliance/ModularCompliance.sol";
import {AssetLiveModule} from "../src/compliance/modules/AssetLiveModule.sol";
import {Token} from "../src/tokens/Token.sol";

/**
 * @title DeployM3
 * @notice T5.1: deploys and wires the whole M3 suite for one asset (ADR 0016), checks its own
 *         wiring, and writes `deployments/<chainid>.json` (T5.1 spec).
 * @dev Inputs come from the environment only; no key is in any committed file. Steps 1-9
 *      and 12 of spec §2. Registering the asset and `setTokenFor` happen at onboarding
 *      (T6.1a, spec §3), so the token is deployed bound to no asset and its mints fail
 *      closed. When `M3_OWNER_PK` is absent (a multisig on a real chain), every contract is
 *      still deployed, the owner calls are printed as `to / data` for the multisig, and the
 *      unpause and wiring check are left for after the multisig has executed them.
 *      `smoke()` (anvil only) onboards a FIXTURE lot end to end.
 */
contract DeployM3 is Script {
    uint256 internal constant ANVIL_CHAIN_ID = 31337;
    uint256 internal constant CLAIM_PURPOSE = 3;
    uint256 internal constant ECDSA_KEY_TYPE = 1;

    struct Config {
        address owner;
        uint256 ownerPk; // 0 when the owner is a multisig without a local key
        address agent;
        uint256 agentPk;
        address kycIssuerKey;
        uint256 kycIssuerPk;
        string assetRef;
        string tokenName;
        string tokenSymbol;
        uint64 valuationWindow;
        address identityStorage; // 0 = deploy a new shared storage
    }

    struct Deployment {
        address kycIssuer;
        ClaimTopicsRegistry claimTopicsRegistry;
        TrustedIssuersRegistry trustedIssuersRegistry;
        IdentityRegistryStorage identityRegistryStorage;
        IdentityRegistry identityRegistry;
        AssetRegistry assetRegistry;
        CustodianAttestationSource attestationSource;
        ModularCompliance compliance;
        AssetLiveModule assetLiveModule;
        Token token;
    }

    error OwnerMustBeContract(address owner);
    error KeyMismatch(string role, address expected, address fromKey);
    error WiringMismatch(string what);
    error SmokeIsLocalOnly();
    error ArtifactDeployFailed(string artifact);

    struct OwnerCall {
        address to;
        bytes data;
    }

    OwnerCall[] internal _pendingOwnerCalls;

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------

    /// @notice Deploys, wires, unpauses, self-checks and writes the deployment file.
    function run() external returns (Deployment memory d) {
        Config memory c = _config();
        d = _deploy(c);
        if (c.ownerPk == 0) {
            _printPendingOwnerCalls();
            console2.log("Owner calls pending: unpause and wiring check run after the multisig executes them.");
        } else {
            vm.broadcast(c.agentPk);
            d.token.unpause(); // step 12, last
            verifyWiring(d, c);
        }
        _writeDeployment(d, c);
    }

    /**
     * @notice Anvil only: deploys, then onboards a FIXTURE lot end to end (T5.3 smoke): a
     *         KYC'd treasury wallet, register, bind, attest, admit, mint.
     */
    function smoke() external returns (Deployment memory d) {
        if (block.chainid != ANVIL_CHAIN_ID) revert SmokeIsLocalOnly();
        Config memory c = _config();
        if (c.ownerPk == 0) revert KeyMismatch("owner", c.owner, address(0));
        d = _deploy(c);
        vm.broadcast(c.agentPk);
        d.token.unpause();
        verifyWiring(d, c);

        // FIXTURE lot (T6 spec §9.1): not real data.
        bytes32 assetId = keccak256(bytes(c.assetRef));
        uint256 reserve = 999.9e18; // one 1 kg bar at 999.9 fine, in fine grams (ADR 0020)
        address treasury = c.agent;

        vm.startBroadcast(c.agentPk);
        IIdentity treasuryId =
            IIdentity(_deployArtifact("Identity.sol:Identity", abi.encode(treasury, false), "Identity"));
        bytes memory data = abi.encode("FIXTURE kyc", KYC_TOPIC);
        bytes32 dataHash = keccak256(abi.encode(address(treasuryId), KYC_TOPIC, data));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(c.kycIssuerPk, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)));
        treasuryId.addClaim(KYC_TOPIC, 1, d.kycIssuer, abi.encodePacked(r, s, v), data, "");
        d.identityRegistry.registerIdentity(treasury, treasuryId, 586);
        d.assetRegistry.register(assetId, keccak256("FIXTURE metadata"), c.assetRef);
        vm.stopBroadcast();

        vm.broadcast(c.ownerPk);
        d.assetRegistry.setTokenFor(assetId, address(d.token));

        vm.startBroadcast(c.agentPk);
        d.attestationSource
            .submitAttestation(
                IReserveAttestationSource.ReserveAttestation(assetId, reserve, 1, uint64(block.timestamp)),
                keccak256("FIXTURE envelope")
            );
        d.assetRegistry.admit(assetId, reserve);
        d.token.mint(treasury, reserve);
        vm.stopBroadcast();

        console2.log("SMOKE OK: FIXTURE lot LIVE, supply", d.token.totalSupply());
        _writeDeployment(d, c);
    }

    /// @notice Reverts `WiringMismatch(what)` unless the deployment matches spec §4.
    function verifyWiring(Deployment memory d, Config memory c) public view {
        Token t = d.token;
        _check(address(t.identityRegistry()) == address(d.identityRegistry), "token.identityRegistry");
        _check(address(t.compliance()) == address(d.compliance), "token.compliance");
        _check(d.compliance.getTokenBound() == address(t), "compliance.token");
        _check(d.compliance.isModuleBound(address(d.assetLiveModule)), "compliance.module");
        _check(address(d.assetLiveModule.registry()) == address(d.assetRegistry), "module.registry");
        _check(address(d.identityRegistry.identityStorage()) == address(d.identityRegistryStorage), "ir.storage");
        _check(address(d.identityRegistry.issuersRegistry()) == address(d.trustedIssuersRegistry), "ir.issuers");
        _check(address(d.identityRegistry.topicsRegistry()) == address(d.claimTopicsRegistry), "ir.topics");
        uint256[] memory topics = d.claimTopicsRegistry.getClaimTopics();
        _check(topics.length == 1 && topics[0] == KYC_TOPIC, "topics.kycOnly");
        _check(d.trustedIssuersRegistry.hasClaimTopic(d.kycIssuer, KYC_TOPIC), "issuers.kyc");
        _check(d.assetRegistry.attestationSource() == address(d.attestationSource), "registry.source");
        _check(d.assetRegistry.valuationWindowOf(bytes32(0)) == c.valuationWindow, "registry.window");
        _check(d.assetRegistry.isAgent(c.agent), "registry.agent");
        _check(t.isAgent(c.agent), "token.agent");
        _check(d.identityRegistry.isAgent(c.agent), "ir.agent");
        _check(d.identityRegistry.isAgent(address(t)), "ir.tokenAgent");
        _check(d.attestationSource.isSubmitter(c.agent), "source.submitter");
        _check(d.claimTopicsRegistry.owner() == c.owner, "owner.topics");
        _check(d.trustedIssuersRegistry.owner() == c.owner, "owner.issuers");
        _check(d.identityRegistryStorage.owner() == c.owner, "owner.storage");
        _check(d.identityRegistry.owner() == c.owner, "owner.ir");
        _check(d.assetRegistry.owner() == c.owner, "owner.registry");
        _check(d.attestationSource.owner() == c.owner, "owner.source");
        _check(d.compliance.owner() == c.owner, "owner.compliance");
        _check(t.owner() == c.owner, "owner.token");
        _check(!t.paused(), "token.paused");
    }

    // ------------------------------------------------------------------
    // Deployment
    // ------------------------------------------------------------------

    function _config() internal view returns (Config memory c) {
        c.owner = vm.envAddress("M3_OWNER");
        c.ownerPk = vm.envOr("M3_OWNER_PK", uint256(0));
        c.agent = vm.envAddress("M3_AGENT");
        c.agentPk = vm.envUint("M3_AGENT_PK");
        c.kycIssuerKey = vm.envAddress("M3_KYC_ISSUER_KEY");
        c.kycIssuerPk = vm.envUint("M3_KYC_ISSUER_PK");
        c.assetRef = vm.envString("M3_ASSET_REF");
        c.tokenName = vm.envString("M3_TOKEN_NAME");
        c.tokenSymbol = vm.envString("M3_TOKEN_SYMBOL");
        c.valuationWindow = uint64(vm.envOr("M3_VALUATION_WINDOW", uint256(86400))); // ADR 0018
        c.identityStorage = vm.envOr("M3_IDENTITY_STORAGE", address(0));

        if (c.ownerPk != 0 && vm.addr(c.ownerPk) != c.owner) revert KeyMismatch("owner", c.owner, vm.addr(c.ownerPk));
        if (vm.addr(c.agentPk) != c.agent) revert KeyMismatch("agent", c.agent, vm.addr(c.agentPk));
        if (vm.addr(c.kycIssuerPk) != c.kycIssuerKey) {
            revert KeyMismatch("kycIssuer", c.kycIssuerKey, vm.addr(c.kycIssuerPk));
        }
        if (block.chainid != ANVIL_CHAIN_ID && c.owner.code.length == 0) revert OwnerMustBeContract(c.owner);
        if (c.owner.code.length == 0) {
            console2.log(unicode"OWNER IS AN EOA — local only, not ADR 0015 conformant");
        }
    }

    function _deploy(Config memory c) internal returns (Deployment memory d) {
        // Constructors only take addresses, so the agent key pays for every deployment.
        vm.startBroadcast(c.agentPk);
        d.claimTopicsRegistry = new ClaimTopicsRegistry(c.owner); // 1
        d.trustedIssuersRegistry = new TrustedIssuersRegistry(c.owner); // 3
        d.identityRegistryStorage = c.identityStorage == address(0)
            ? new IdentityRegistryStorage(c.owner)
            : IdentityRegistryStorage(c.identityStorage); // 4
        d.identityRegistry = new IdentityRegistry(
            c.owner,
            ITrustedIssuersRegistry(address(d.trustedIssuersRegistry)),
            IClaimTopicsRegistry(address(d.claimTopicsRegistry)),
            IIdentityRegistryStorage(address(d.identityRegistryStorage))
        ); // 5
        d.assetRegistry = new AssetRegistry(c.owner); // 6
        d.attestationSource = new CustodianAttestationSource(c.owner); // 7
        d.compliance = new ModularCompliance(c.owner); // 8
        d.assetLiveModule = new AssetLiveModule(IAssetRegistry(address(d.assetRegistry)));
        d.token = new Token(
            c.owner, address(d.identityRegistry), address(d.compliance), c.tokenName, c.tokenSymbol, address(0)
        ); // 9
        vm.stopBroadcast();

        // 2: the project KYC ClaimIssuer (vendored onchain-id, Q23), from the issuer key.
        vm.startBroadcast(c.kycIssuerPk);
        d.kycIssuer = _deployArtifact("ClaimIssuer.sol:ClaimIssuer", abi.encode(c.kycIssuerKey), "ClaimIssuer");
        IClaimIssuer(d.kycIssuer).addKey(keccak256(abi.encode(c.kycIssuerKey)), CLAIM_PURPOSE, ECDSA_KEY_TYPE);
        vm.stopBroadcast();

        uint256[] memory kyc = new uint256[](1);
        kyc[0] = KYC_TOPIC;
        _ownerCall(c, address(d.claimTopicsRegistry), abi.encodeCall(ClaimTopicsRegistry.addClaimTopic, (KYC_TOPIC)));
        _ownerCall(
            c,
            address(d.trustedIssuersRegistry),
            abi.encodeCall(TrustedIssuersRegistry.addTrustedIssuer, (IClaimIssuer(d.kycIssuer), kyc))
        );
        _ownerCall(
            c,
            address(d.identityRegistryStorage),
            abi.encodeCall(IdentityRegistryStorage.bindIdentityRegistry, (address(d.identityRegistry)))
        );
        _ownerCall(c, address(d.identityRegistry), abi.encodeWithSignature("addAgent(address)", c.agent));
        _ownerCall(c, address(d.assetRegistry), abi.encodeCall(AssetRegistry.addAgent, (c.agent)));
        _ownerCall(c, address(d.assetRegistry), abi.encodeCall(AssetRegistry.setValuationWindow, (c.valuationWindow)));
        _ownerCall(c, address(d.attestationSource), abi.encodeCall(CustodianAttestationSource.addSubmitter, (c.agent)));
        _ownerCall(
            c,
            address(d.assetRegistry),
            abi.encodeCall(AssetRegistry.setAttestationSource, (address(d.attestationSource)))
        );
        _ownerCall(c, address(d.compliance), abi.encodeCall(ModularCompliance.addModule, (address(d.assetLiveModule))));
        _ownerCall(c, address(d.token), abi.encodeWithSignature("addAgent(address)", c.agent));
        _ownerCall(c, address(d.identityRegistry), abi.encodeWithSignature("addAgent(address)", address(d.token)));
    }

    /// @dev Sends an owner call when the owner key is local, otherwise queues it for the multisig.
    function _ownerCall(Config memory c, address to, bytes memory data) internal {
        if (c.ownerPk == 0) {
            _pendingOwnerCalls.push(OwnerCall(to, data));
            return;
        }
        vm.broadcast(c.ownerPk);
        (bool ok, bytes memory ret) = to.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function _printPendingOwnerCalls() internal view {
        console2.log("OWNER CALLS for the multisig, in order (to / data):");
        for (uint256 i; i < _pendingOwnerCalls.length; ++i) {
            console2.log(_pendingOwnerCalls[i].to);
            console2.logBytes(_pendingOwnerCalls[i].data);
        }
    }

    /// @dev Deploys a vendored 0.8.17 artifact with CREATE so it is broadcast like any other deploy.
    function _deployArtifact(string memory artifact, bytes memory args, string memory label)
        internal
        returns (address addr)
    {
        bytes memory code = abi.encodePacked(vm.getCode(artifact), args);
        assembly {
            addr := create(0, add(code, 32), mload(code))
        }
        if (addr == address(0)) revert ArtifactDeployFailed(label);
    }

    function _check(bool ok, string memory what) internal pure {
        if (!ok) revert WiringMismatch(what);
    }

    function _writeDeployment(Deployment memory d, Config memory c) internal {
        string memory k = "m3";
        vm.serializeUint(k, "chainId", block.chainid);
        vm.serializeAddress(k, "owner", c.owner);
        vm.serializeAddress(k, "agent", c.agent);
        vm.serializeAddress(k, "kycIssuer", d.kycIssuer);
        vm.serializeAddress(k, "claimTopicsRegistry", address(d.claimTopicsRegistry));
        vm.serializeAddress(k, "trustedIssuersRegistry", address(d.trustedIssuersRegistry));
        vm.serializeAddress(k, "identityRegistryStorage", address(d.identityRegistryStorage));
        vm.serializeAddress(k, "identityRegistry", address(d.identityRegistry));
        vm.serializeAddress(k, "assetRegistry", address(d.assetRegistry));
        vm.serializeAddress(k, "attestationSource", address(d.attestationSource));
        vm.serializeAddress(k, "compliance", address(d.compliance));
        vm.serializeAddress(k, "assetLiveModule", address(d.assetLiveModule));
        vm.serializeAddress(k, "token", address(d.token));
        vm.serializeString(k, "assetRef", c.assetRef);
        vm.serializeUint(k, "valuationWindow", c.valuationWindow);
        string memory json = vm.serializeString(k, "gitCommit", vm.envOr("GIT_COMMIT", string("unknown")));
        vm.writeJson(json, string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json"));
    }
}
