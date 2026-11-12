// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ClaimTopicsRegistry} from "../../src/registry/ClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsHandler
 * @notice Exposes the registry's two mutating functions to the invariant fuzzer, as the owner.
 * @dev Topics are drawn from a small range that includes `KYC_TOPIC`, so the fuzzer hits
 *      duplicates, removals of KYC and removals of unknown topics often, not by luck.
 *      Reverts are swallowed: a refused call is a legal outcome, and the invariant is what
 *      must hold afterwards.
 */
contract ClaimTopicsHandler is Test {
    ClaimTopicsRegistry internal immutable reg;
    address internal immutable owner;

    uint256 internal constant TOPIC_RANGE = 20;

    constructor(ClaimTopicsRegistry reg_, address owner_) {
        reg = reg_;
        owner = owner_;
    }

    function addClaimTopic(uint256 seed) external {
        vm.prank(owner);
        try reg.addClaimTopic(bound(seed, 0, TOPIC_RANGE)) {} catch {}
    }

    function removeClaimTopic(uint256 seed) external {
        vm.prank(owner);
        try reg.removeClaimTopic(bound(seed, 0, TOPIC_RANGE)) {} catch {}
    }
}

/**
 * @title ClaimTopicsRegistryInvariantTest
 * @notice AC-T1-17: the topic set's full state contract holds after every sequence of calls.
 * @dev The three properties below are what make `IdentityRegistry.isVerified` fail-closed,
 *      and each is maintained by one of the registry's guards, so this tests the guards as a
 *      system. It protects future edits too, such as an index-based remove, where a case
 *      analysis of today's code would not (T1 thread, AC-T1-17).
 *
 *      "Never empty" is deliberately NOT asserted: it is implied by "KYC appears exactly
 *      once", so it could never be the only failing line (refined AC-11). The empty case is
 *      diagnosed instead by the KYC assertion's message, which reports the set's length. Do
 *      not re-add it as a separate assertion.
 */
contract ClaimTopicsRegistryInvariantTest is Test {
    ClaimTopicsRegistry internal reg;
    ClaimTopicsHandler internal handler;

    function setUp() public {
        address owner = makeAddr("owner (2-of-3 multisig)");
        reg = new ClaimTopicsRegistry(owner);
        handler = new ClaimTopicsHandler(reg, owner);
        targetContract(address(handler));
    }

    /// @dev 64 x 128 is a LOCAL-SPEED setting, not the considered coverage. At Foundry's default
    ///      (256 runs x depth 500 = 128,000 calls) this one test took ~200 s and made every local
    ///      `forge test` slow. 8,192 calls is enough here only because the reachable state space is
    ///      tiny (subsets of 21 topics containing KYC, at most 15 held). CI runs deeper:
    ///      under FOUNDRY_PROFILE=ci, AC-T1-18. Verified: an inline `default.*` setting ALSO overrides
    ///      `[profile.ci.invariant]`, so the CI depth must be pinned inline too (the `ci.*` lines).
    /// forge-config: default.invariant.runs = 64
    /// forge-config: default.invariant.depth = 128
    /// forge-config: ci.invariant.runs = 256
    /// forge-config: ci.invariant.depth = 500
    function invariant_TopicSetStaysValid() public view {
        uint256[] memory t = reg.getClaimTopics();
        uint256 kyc = reg.KYC_TOPIC();

        // Bounded: isVerified loops over every topic on every transfer and mint.
        assertLe(t.length, reg.MAX_CLAIM_TOPICS(), "topic set must not exceed MAX_CLAIM_TOPICS");

        uint256 kycCount;
        for (uint256 i = 0; i < t.length; i++) {
            if (t[i] == kyc) kycCount++;
            // No duplicates.
            for (uint256 j = i + 1; j < t.length; j++) {
                assertTrue(t[i] != t[j], "topic set must not contain duplicates");
            }
        }
        // KYC is permanent and present exactly once. The message carries the length, so an empty
        // set (which would make isVerified vacuously true) is diagnosed here.
        assertEq(
            kycCount,
            1,
            string.concat("KYC_TOPIC must appear exactly once (in a set of length ", vm.toString(t.length), ")")
        );
    }
}
