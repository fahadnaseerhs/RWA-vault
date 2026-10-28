// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {M3System} from "../helpers/M3System.sol";
import {Token} from "../../src/tokens/Token.sol";
import {AssetRegistry} from "../../src/registry/AssetRegistry.sol";
import {CustodianAttestationSource} from "../../src/registry/CustodianAttestationSource.sol";
import {IReserveAttestationSource} from "../../src/registry/interfaces/IReserveAttestationSource.sol";

/**
 * @title M3Handler
 * @notice Drives the real suite in random order for T4.5. Mints go THROUGH THE TOKEN, the
 *         only enforcement path (T0.6 §3.3). Ghost variables record what the invariants check.
 */
contract M3Handler is Test {
    Token internal tok;
    AssetRegistry internal reg;
    CustodianAttestationSource internal src;
    bytes32 internal assetId;
    address internal agent;
    address internal owner_;
    address[2] internal holders;
    uint64 internal seq;

    uint256 public ghostMintsBeyondReserve;
    uint256 public ghostMintsWhileNotLiveOrStale;
    bool public ghostDownwardAttestation;
    uint256 public ghostSuccessfulMints;

    constructor(
        Token tok_,
        AssetRegistry reg_,
        CustodianAttestationSource src_,
        bytes32 assetId_,
        address agent_,
        address ownerAddr,
        address a,
        address b,
        uint64 seq_
    ) {
        tok = tok_;
        reg = reg_;
        src = src_;
        assetId = assetId_;
        agent = agent_;
        owner_ = ownerAddr;
        holders = [a, b];
        seq = seq_;
    }

    function _fresh() internal view returns (bool) {
        uint64 ts = reg.valuationTsOf(assetId);
        uint64 w = reg.valuationWindowOf(assetId);
        return w != 0 && ts <= block.timestamp && block.timestamp - ts <= w;
    }

    function mint(uint256 who, uint256 amount) external {
        amount = bound(amount, 0, 2e24);
        bool liveAndFresh = reg.isLive(assetId) && _fresh();
        vm.prank(agent);
        try tok.mint(holders[who % 2], amount) {
            ghostSuccessfulMints++;
            if (tok.totalSupply() > reg.reserveOf(assetId)) ghostMintsBeyondReserve++;
            if (!liveAndFresh) ghostMintsWhileNotLiveOrStale++;
        } catch {}
    }

    function burn(uint256 who, uint256 amount) external {
        address h = holders[who % 2];
        amount = bound(amount, 0, tok.balanceOf(h));
        vm.prank(agent);
        tok.burn(h, amount);
    }

    function transfer(uint256 who, uint256 amount) external {
        address from = holders[who % 2];
        amount = bound(amount, 0, tok.balanceOf(from));
        vm.prank(from);
        tok.transfer(holders[(who + 1) % 2], amount);
    }

    function submitAndAdmit(uint256 reserve, uint256 age) external {
        reserve = bound(reserve, 0, 1e24);
        age = bound(age, 0, 2 hours);
        seq++;
        uint64 ts = uint64(block.timestamp - age);
        uint256 supplyBefore = tok.totalSupply();
        vm.startPrank(agent);
        src.submitAttestation(
            IReserveAttestationSource.ReserveAttestation(assetId, reserve, seq, ts), keccak256(abi.encode(seq))
        );
        try reg.admit(assetId, 0) {
            if (reserve < supplyBefore) ghostDownwardAttestation = true;
        } catch {}
        vm.stopPrank();
    }

    function freeze() external {
        vm.prank(agent);
        try reg.freeze(assetId, "fuzz") {} catch {}
    }

    function unfreeze() external {
        vm.prank(owner_);
        try reg.unfreeze(assetId) {} catch {}
    }

    function warp(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 0, 3 hours));
    }
}

/**
 * @title AttestedSupplyLeReserveTest
 * @notice T4.5 invariants per T3 build spec §7. "supply <= reserve, always" is false by
 *         design (ADR 0019 §3 accepts a downward re-attestation), so the property is
 *         "no mint ever creates supply beyond reserve".
 */
contract AttestedSupplyLeReserveTest is M3System {
    M3Handler internal handler;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        vm.warp(1_800_000_000);
        _deployM3();
        _onboardInvestor(alice, 586);
        _onboardInvestor(bob, 586);
        _onboardAsset(1_000e18);

        handler = new M3Handler(tok, assetRegistry, source, ASSET_ID, irAgent, govOwner, alice, bob, attSeq);
        targetContract(address(handler));
    }

    function invariant_noMintBeyondReserve() public view {
        assertEq(handler.ghostMintsBeyondReserve(), 0);
    }

    function invariant_supplyLeReserveWithoutDownwardAttestation() public view {
        if (!handler.ghostDownwardAttestation()) {
            assertLe(tok.totalSupply(), assetRegistry.reserveOf(ASSET_ID));
        }
    }

    function invariant_noMintWhileNotLiveOrStale() public view {
        assertEq(handler.ghostMintsWhileNotLiveOrStale(), 0);
    }
}
