// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IIdentity} from "../src/identity/interfaces/IIdentity.sol";
import {IERC735} from "../src/identity/interfaces/IERC735.sol";
import {KYC_TOPIC} from "../src/registry/ClaimTopics.sol";
import {IdentityRegistry} from "../src/registry/IdentityRegistry.sol";

/**
 * @title VerifyWallet
 * @notice Devnet KYC helper (T5.1 spec §7): gives a wallet an ONCHAINID with a KYC claim from
 *         the project issuer and registers it, so `isVerified(wallet)` is true. Anvil only.
 * @dev Keys come from the environment: `M3_WALLET_PK` (the wallet, devnet only),
 *      `M3_KYC_ISSUER_PK` and `M3_AGENT_PK`. Addresses come from `deployments/31337.json`.
 *      Run with `--sig "run(address,uint16)" <wallet> <country>`.
 */
contract VerifyWallet is Script {
    uint256 internal constant ANVIL_CHAIN_ID = 31337;

    struct Keys {
        uint256 walletPk;
        uint256 kycIssuerPk;
        uint256 agentPk;
    }

    error VerifyWalletDevnetOnly();
    error KeyMismatch(string role, address expected, address fromKey);
    error ArtifactDeployFailed(string artifact);
    error NotVerifiedAfterRegistration(address wallet);

    function run(address wallet, uint16 country) external returns (IIdentity identity) {
        if (block.chainid != ANVIL_CHAIN_ID) revert VerifyWalletDevnetOnly();
        string memory json = vm.readFile(string.concat(vm.projectRoot(), "/deployments/31337.json"));
        Keys memory k = Keys({
            walletPk: vm.envUint("M3_WALLET_PK"),
            kycIssuerPk: vm.envUint("M3_KYC_ISSUER_PK"),
            agentPk: vm.envUint("M3_AGENT_PK")
        });
        identity = verify(
            wallet,
            country,
            IdentityRegistry(vm.parseJsonAddress(json, ".identityRegistry")),
            vm.parseJsonAddress(json, ".kycIssuer"),
            k
        );
    }

    /// @notice Steps 1-5 of spec §7, with every address and key passed in.
    function verify(address wallet, uint16 country, IdentityRegistry ir, address kycIssuer, Keys memory k)
        public
        returns (IIdentity identity)
    {
        if (block.chainid != ANVIL_CHAIN_ID) revert VerifyWalletDevnetOnly();
        if (vm.addr(k.walletPk) != wallet) revert KeyMismatch("wallet", wallet, vm.addr(k.walletPk));

        // 2-3: the wallet deploys its own identity and adds the issuer-signed KYC claim through
        // `execute`, which auto-approves for its management key.
        vm.startBroadcast(k.walletPk);
        bytes memory code = abi.encodePacked(vm.getCode("Identity.sol:Identity"), abi.encode(wallet, false));
        address addr;
        assembly {
            addr := create(0, add(code, 32), mload(code))
        }
        if (addr == address(0)) revert ArtifactDeployFailed("Identity");
        identity = IIdentity(addr);

        bytes memory data = abi.encode("DEVNET kyc", KYC_TOPIC);
        bytes32 dataHash = keccak256(abi.encode(addr, KYC_TOPIC, data));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(k.kycIssuerPk, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)));
        identity.execute(
            addr, 0, abi.encodeCall(IERC735.addClaim, (KYC_TOPIC, 1, kycIssuer, abi.encodePacked(r, s, v), data, ""))
        );
        vm.stopBroadcast();

        // 4: the agent registers it.
        vm.broadcast(k.agentPk);
        ir.registerIdentity(wallet, identity, country);

        // 5
        if (!ir.isVerified(wallet)) revert NotVerifiedAfterRegistration(wallet);
        console2.log("VERIFIED wallet", wallet);
        console2.log("  identity", addr);
    }
}
