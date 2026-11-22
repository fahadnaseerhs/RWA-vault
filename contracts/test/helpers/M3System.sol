// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IdentityFixtures} from "../identity/IdentityFixtures.sol";
import {AssetRegistry} from "../../src/registry/AssetRegistry.sol";
import {IAssetRegistry} from "../../src/registry/interfaces/IAssetRegistry.sol";
import {CustodianAttestationSource} from "../../src/registry/CustodianAttestationSource.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";
import {ModularCompliance} from "../../src/compliance/ModularCompliance.sol";
import {AssetLiveModule} from "../../src/compliance/modules/AssetLiveModule.sol";
import {Token} from "../../src/tokens/Token.sol";

/**
 * @title M3System
 * @notice Deploys and wires the whole M3 suite with real contracts, in the T5.1 order
 *         (T5.1 spec §2), for one asset. Shared by the T3.6 acceptance suite, the token
 *         unit tests and the T4.5 invariant. `irAgent` is the single Tier 1 key.
 */
abstract contract M3System is IdentityFixtures {
    uint64 internal constant WINDOW = 1 hours; // tests use a short tau (Q13 test rule)

    AssetRegistry internal assetRegistry;
    CustodianAttestationSource internal source;
    ModularCompliance internal mc;
    AssetLiveModule internal liveModule;
    Token internal tok;

    string internal constant ASSET_REF = "gold-lot-001";
    bytes32 internal ASSET_ID = keccak256(bytes(ASSET_REF));
    uint64 internal attSeq;

    /// @dev T5.1 steps 1-9 and 12: everything wired, token unpaused, no asset bound yet.
    function _deployM3() internal {
        _deployIdentityLayer();
        assetRegistry = new AssetRegistry(govOwner);
        source = new CustodianAttestationSource(govOwner);
        mc = new ModularCompliance(govOwner);
        liveModule = new AssetLiveModule(IAssetRegistry(address(assetRegistry)));

        vm.startPrank(govOwner);
        assetRegistry.addAgent(irAgent);
        assetRegistry.setValuationWindow(WINDOW);
        source.addSubmitter(irAgent);
        assetRegistry.setAttestationSource(address(source));
        mc.addModule(address(liveModule));
        tok = new Token(govOwner, address(ir), address(mc), "QORA Gold Lot 001", "qXAU-001", address(0));
        tok.addAgent(irAgent);
        ir.addAgent(address(tok));
        vm.stopPrank();

        vm.prank(irAgent);
        tok.unpause();
    }

    /// @dev T6.1a steps 10-11: register, bind, attest, admit. Leaves the asset LIVE.
    function _onboardAsset(uint256 reserve) internal {
        vm.prank(irAgent);
        assetRegistry.register(ASSET_ID, keccak256("fixture-metadata"), ASSET_REF);
        vm.prank(govOwner);
        assetRegistry.setTokenFor(ASSET_ID, address(tok));
        _attestAndAdmit(reserve);
    }

    /// @dev Submits a fresh attestation through the real source and admits it.
    function _attestAndAdmit(uint256 reserve) internal {
        attSeq++;
        vm.startPrank(irAgent);
        source.submitAttestation(
            IReserveAttestationSource.ReserveAttestation(ASSET_ID, reserve, attSeq, uint64(block.timestamp)),
            keccak256(abi.encode("envelope", attSeq))
        );
        assetRegistry.admit(ASSET_ID, 0);
        vm.stopPrank();
    }
}
