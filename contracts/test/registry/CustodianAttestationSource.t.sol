// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {CustodianAttestationSource} from "../../src/registry/CustodianAttestationSource.sol";
import {AssetRegistry} from "../../src/registry/AssetRegistry.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";

/**
 * @title CustodianAttestationSourceTest
 * @notice T4.3: the MS1 source per the T4 Researcher rulings round 1 (ADR 0017, ADR 0027).
 */
contract CustodianAttestationSourceTest is Test {
    CustodianAttestationSource internal src;
    address internal owner = makeAddr("owner");
    address internal submitter = makeAddr("submitter");
    address internal stranger = makeAddr("stranger");

    string internal constant REF = "gold-lot-001";
    bytes32 internal ID = keccak256(bytes(REF));
    bytes32 internal constant ENV = keccak256("envelope-bytes");

    function setUp() public {
        vm.warp(1_800_000_000);
        src = new CustodianAttestationSource(owner);
        vm.prank(owner);
        src.addSubmitter(submitter);
    }

    function _att(uint64 seq) internal view returns (IReserveAttestationSource.ReserveAttestation memory) {
        return IReserveAttestationSource.ReserveAttestation(ID, 999.9e18, seq, uint64(block.timestamp));
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.NotOwner.selector, address(0)));
        new CustodianAttestationSource(address(0));
    }

    function test_SubmitStoresAndEmits() public {
        assertFalse(src.hasAttestation(ID));
        vm.expectEmit(true, true, false, true, address(src));
        emit CustodianAttestationSource.AttestationSubmitted(ID, 1, 999.9e18, uint64(block.timestamp), ENV, submitter);
        vm.prank(submitter);
        src.submitAttestation(_att(1), ENV);

        assertTrue(src.hasAttestation(ID));
        assertEq(src.envelopeHashOf(ID), ENV);
        IReserveAttestationSource.ReserveAttestation memory a = src.latest(ID);
        assertEq(a.assetId, ID);
        assertEq(a.reserve, 999.9e18);
        assertEq(a.seq, 1);
        assertEq(a.valuationTs, uint64(block.timestamp));
    }

    function test_ZeroReserveAccepted() public {
        IReserveAttestationSource.ReserveAttestation memory a = _att(1);
        a.reserve = 0;
        vm.prank(submitter);
        src.submitAttestation(a, ENV);
        assertTrue(src.hasAttestation(ID));
        assertEq(src.latest(ID).reserve, 0);
    }

    function test_SubmitOnlySubmitter() public {
        IReserveAttestationSource.ReserveAttestation memory a = _att(1);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.NotAuthorisedSubmitter.selector, stranger));
        src.submitAttestation(a, ENV);
    }

    function test_SubmitRejections() public {
        IReserveAttestationSource.ReserveAttestation memory a = _att(1);
        a.assetId = bytes32(0);
        vm.startPrank(submitter);
        vm.expectRevert(CustodianAttestationSource.EmptyAssetId.selector);
        src.submitAttestation(a, ENV);
        vm.expectRevert(CustodianAttestationSource.MissingEnvelopeHash.selector);
        src.submitAttestation(_att(1), bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.SequenceNotIncreasing.selector, 0, 0));
        src.submitAttestation(_att(0), ENV);
        src.submitAttestation(_att(3), ENV);
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.SequenceNotIncreasing.selector, 3, 3));
        src.submitAttestation(_att(3), ENV);
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.SequenceNotIncreasing.selector, 2, 3));
        src.submitAttestation(_att(2), ENV);
        vm.stopPrank();
    }

    function test_SubmitterManagement() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.InvalidSubmitter.selector, address(0)));
        src.addSubmitter(address(0));
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.InvalidSubmitter.selector, address(0)));
        src.removeSubmitter(address(0));
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.SubmitterUnchanged.selector, submitter));
        src.addSubmitter(submitter);
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.SubmitterUnchanged.selector, stranger));
        src.removeSubmitter(stranger);
        vm.expectEmit(true, false, false, false, address(src));
        emit CustodianAttestationSource.SubmitterRemoved(submitter);
        src.removeSubmitter(submitter);
        vm.stopPrank();
        assertFalse(src.isSubmitter(submitter));

        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.NotOwner.selector, stranger));
        src.addSubmitter(stranger);
        vm.expectRevert(abi.encodeWithSelector(CustodianAttestationSource.NotOwner.selector, stranger));
        src.removeSubmitter(submitter);
        vm.stopPrank();
    }

    /// Integration: submit, then admit on the real registry, then LIVE.
    function test_SubmitThenAdmitGoesLive() public {
        AssetRegistry reg = new AssetRegistry(owner);
        address agent = makeAddr("agent");
        vm.startPrank(owner);
        reg.addAgent(agent);
        reg.setAttestationSource(address(src));
        reg.setValuationWindow(1 hours);
        vm.stopPrank();

        vm.prank(agent);
        reg.register(ID, bytes32(0), REF);
        vm.prank(submitter);
        src.submitAttestation(_att(1), ENV);
        vm.prank(agent);
        reg.admit(ID, 999.9e18);

        assertTrue(reg.isLive(ID));
        assertEq(reg.reserveOf(ID), 999.9e18);
        assertEq(reg.lastSequenceOf(ID), 1);
    }
}
