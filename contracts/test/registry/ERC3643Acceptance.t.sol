// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC3643} from "../../src/tokens/interfaces/IERC3643.sol";
import {IIdentityRegistry} from "../../src/registry/interfaces/IIdentityRegistry.sol";

/**
 * @title ERC3643AcceptanceTest
 * @notice Behaviour contract for the ERC-3643 permissioned token (Module 3, Registry).
 * @dev This is the interface-first acceptance spec required by CONTRIBUTING.md:
 *      it is written against the interfaces only and encodes the merge bar every
 *      future implementation must satisfy. It is `abstract` on purpose — Forge does
 *      not run abstract test contracts, so it compiles in CI today without any
 *      implementation present. The implementation PR provides a concrete subclass
 *      that overrides {deploySystem} to deploy and wire a real ERC-3643 system, and
 *      the assertions below then execute unchanged.
 *
 *      Maps directly to the project vision: a verified investor can hold and move
 *      the tokenised real-world asset; an unverified wallet cannot receive it; and
 *      an agent can freeze and pause to keep the asset controllable.
 */
abstract contract ERC3643AcceptanceTest is Test {
    IERC3643 internal token;
    IIdentityRegistry internal registry;

    address internal agent = makeAddr("agent");
    address internal alice = makeAddr("alice"); // registered + verified
    address internal bob = makeAddr("bob"); // registered + verified
    address internal carol = makeAddr("carol"); // NOT verified

    /**
     * @dev Implementation PRs override this to:
     *      - deploy token, identity registry, storage, claim-topics, trusted-issuers
     *        and modular compliance, wired together;
     *      - make `agent` an agent of the token;
     *      - register `alice` and `bob` as verified, leave `carol` unverified;
     *      - assign `token` and `registry`.
     */
    function deploySystem() internal virtual;

    function setUp() public {
        deploySystem();
    }

    /// @dev A verified wallet can receive freshly minted tokens.
    function test_VerifiedWalletCanReceiveMint() public {
        vm.prank(agent);
        token.mint(alice, 1_000e18);
        assertEq(token.balanceOf(alice), 1_000e18);
    }

    /// @dev Minting to an unverified wallet must revert — the core RWA guarantee.
    function test_MintToUnverifiedWalletReverts() public {
        vm.prank(agent);
        vm.expectRevert();
        token.mint(carol, 1_000e18);
    }

    /// @dev A transfer between two verified wallets succeeds.
    function test_VerifiedToVerifiedTransferSucceeds() public {
        vm.prank(agent);
        token.mint(alice, 1_000e18);

        vm.prank(alice);
        token.transfer(bob, 400e18);

        assertEq(token.balanceOf(alice), 600e18);
        assertEq(token.balanceOf(bob), 400e18);
    }

    /// @dev A transfer to an unverified wallet must revert.
    function test_TransferToUnverifiedWalletReverts() public {
        vm.prank(agent);
        token.mint(alice, 1_000e18);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(carol, 1e18);
    }

    /// @dev A frozen wallet cannot send tokens until unfrozen.
    function test_FrozenWalletCannotTransfer() public {
        vm.prank(agent);
        token.mint(alice, 1_000e18);

        vm.prank(agent);
        token.setAddressFrozen(alice, true);
        assertTrue(token.isFrozen(alice));

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1e18);
    }

    /// @dev While paused, no transfers are possible even between verified wallets.
    function test_PausedTokenBlocksTransfer() public {
        vm.prank(agent);
        token.mint(alice, 1_000e18);

        vm.prank(agent);
        token.pause();
        assertTrue(token.paused());

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1e18);
    }

    /// @dev The registry reflects verification status consistently with the token's gate.
    function test_RegistryVerificationMatchesHolders() public view {
        assertTrue(registry.isVerified(alice));
        assertTrue(registry.isVerified(bob));
        assertFalse(registry.isVerified(carol));
    }
}
