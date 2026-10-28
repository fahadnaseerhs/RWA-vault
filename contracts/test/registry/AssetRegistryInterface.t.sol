// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IAssetRegistry, MAX_VALUATION_WINDOW} from "../../src/registry/interfaces/IAssetRegistry.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";
import {IModularCompliance} from "../../src/compliance/interfaces/IModularCompliance.sol";

/**
 * @title AssetRegistryMock
 * @notice Minimal, complete implementation of {IAssetRegistry} that implements nothing.
 * @dev Exists to prove the interface is implementable as written: a signature that
 *      cannot be implemented fails to compile here. Every function reverts
 *      {NotImplemented}. T2.2, T6.1a and T6.1b may build against it before T4.1 lands.
 */
contract AssetRegistryMock is IAssetRegistry {
    /// @notice Every function of this mock reverts with this error.
    error NotImplemented();

    function stateOf(bytes32) external pure returns (AssetState) {
        revert NotImplemented();
    }

    function isLive(bytes32) external pure returns (bool) {
        revert NotImplemented();
    }

    function reserveOf(bytes32) external pure returns (uint256) {
        revert NotImplemented();
    }

    function attestedSupplyOf(bytes32) external pure returns (uint256) {
        revert NotImplemented();
    }

    function lastSequenceOf(bytes32) external pure returns (uint64) {
        revert NotImplemented();
    }

    function valuationTsOf(bytes32) external pure returns (uint64) {
        revert NotImplemented();
    }

    function metadataHashOf(bytes32) external pure returns (bytes32) {
        revert NotImplemented();
    }

    function assetRefOf(bytes32) external pure returns (string memory) {
        revert NotImplemented();
    }

    function tokenOf(bytes32) external pure returns (address) {
        revert NotImplemented();
    }

    function valuationWindowOf(bytes32) external pure returns (uint64) {
        revert NotImplemented();
    }

    function attestationSource() external pure returns (address) {
        revert NotImplemented();
    }

    function assetOfToken(address) external pure returns (bytes32) {
        revert NotImplemented();
    }

    function isAgent(address) external pure returns (bool) {
        revert NotImplemented();
    }

    function register(bytes32, bytes32, string calldata) external pure {
        revert NotImplemented();
    }

    function admit(bytes32, uint256) external pure {
        revert NotImplemented();
    }

    function freeze(bytes32, string calldata) external pure {
        revert NotImplemented();
    }

    function unfreeze(bytes32) external pure {
        revert NotImplemented();
    }

    function setValuationWindow(uint64) external pure {
        revert NotImplemented();
    }

    function setValuationWindowFor(bytes32, uint64) external pure {
        revert NotImplemented();
    }

    function setAttestationSource(address) external pure {
        revert NotImplemented();
    }

    function setTokenFor(bytes32, address) external pure {
        revert NotImplemented();
    }

    function addAgent(address) external pure {
        revert NotImplemented();
    }

    function removeAgent(address) external pure {
        revert NotImplemented();
    }
}

/**
 * @title AssetRegistryInterfaceTest
 * @notice Structural checks on the T0.6 interface (AC-T06-3, AC-T06-7). There is no
 *         behaviour to test yet; the admission predicate is T4.2.
 */
contract AssetRegistryInterfaceTest is Test {
    AssetRegistryMock internal mock;

    function setUp() public {
        mock = new AssetRegistryMock();
    }

    /// AC-T06-3: unknown ids read as UNREGISTERED from zeroed storage.
    function test_UnregisteredIsIndexZero() public pure {
        assertEq(uint8(IAssetRegistry.AssetState.UNREGISTERED), 0);
        assertEq(uint8(IAssetRegistry.AssetState.PENDING), 1);
        assertEq(uint8(IAssetRegistry.AssetState.LIVE), 2);
        assertEq(uint8(IAssetRegistry.AssetState.FROZEN), 3);
    }

    /// AC-T06-7: the mock is a complete IAssetRegistry, reachable through the interface type.
    function test_MockImplementsInterface() public {
        IAssetRegistry registry = IAssetRegistry(address(mock));
        vm.expectRevert(AssetRegistryMock.NotImplemented.selector);
        registry.stateOf(keccak256("gold-lot-001"));
        vm.expectRevert(AssetRegistryMock.NotImplemented.selector);
        registry.admit(keccak256("gold-lot-001"), 1e21);
    }

    /// ADR 0019: `assetId` is the first member, so it is the first word of the encoded struct.
    function test_ReserveAttestationLeadsWithAssetId() public pure {
        bytes32 id = keccak256("gold-lot-001");
        IReserveAttestationSource.ReserveAttestation memory a =
            IReserveAttestationSource.ReserveAttestation({assetId: id, reserve: 1e21, seq: 3, valuationTs: 1761523200});
        bytes memory enc = abi.encode(a);
        bytes32 firstWord;
        assembly {
            firstWord := mload(add(enc, 32))
        }
        assertEq(firstWord, id);
    }

    /// Fix spec A5: our binding event never shares a name or topic with IModularCompliance.TokenBound.
    function test_AssetTokenBoundTopicDiffersFromCompliance() public pure {
        assertEq(IAssetRegistry.AssetTokenBound.selector, keccak256("AssetTokenBound(bytes32,address)"));
        assertEq(IModularCompliance.TokenBound.selector, keccak256("TokenBound(address)"));
        assertTrue(IAssetRegistry.AssetTokenBound.selector != IModularCompliance.TokenBound.selector);
    }

    /// Fix spec §14.4: the window bound is one pinned value.
    function test_MaxValuationWindowIsOneYear() public pure {
        assertEq(MAX_VALUATION_WINDOW, 365 days);
    }

    /// AC-T06-7: no two rejection stamps share a 4-byte selector (registry's 22 + the source's clause 1).
    function test_ErrorSelectorsAreDistinct() public pure {
        bytes4[23] memory s = [
            IAssetRegistry.StaleSequence.selector,
            IAssetRegistry.ReserveTooLow.selector,
            IAssetRegistry.ValuationStale.selector,
            IAssetRegistry.ValuationInFuture.selector,
            IAssetRegistry.AssetNotRegistered.selector,
            IAssetRegistry.AssetAlreadyRegistered.selector,
            IAssetRegistry.AssetNotLive.selector,
            IAssetRegistry.AssetNotFrozen.selector,
            IAssetRegistry.EmptyAssetId.selector,
            IAssetRegistry.AssetRefMismatch.selector,
            IAssetRegistry.NoAttestation.selector,
            IAssetRegistry.TokenNotBound.selector,
            IAssetRegistry.NotAuthorisedAgent.selector,
            IAssetRegistry.NotOwner.selector,
            IAssetRegistry.InvalidAgent.selector,
            IAssetRegistry.AgentUnchanged.selector,
            IAssetRegistry.InvalidValuationWindow.selector,
            IAssetRegistry.InvalidAttestationSource.selector,
            IAssetRegistry.AssetIdMismatch.selector,
            IAssetRegistry.TokenAlreadyBound.selector,
            IAssetRegistry.AssetAlreadyHasToken.selector,
            IAssetRegistry.InvalidTokenBinding.selector,
            IReserveAttestationSource.BadAttestationSig.selector
        ];
        for (uint256 i = 0; i < s.length; i++) {
            for (uint256 j = i + 1; j < s.length; j++) {
                assertTrue(s[i] != s[j], "duplicate error selector");
            }
        }
    }
}
