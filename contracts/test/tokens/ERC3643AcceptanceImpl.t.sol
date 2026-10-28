// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {ERC3643AcceptanceTest} from "../registry/ERC3643Acceptance.t.sol";
import {M3System} from "../helpers/M3System.sol";
import {IERC3643} from "../../src/tokens/interfaces/IERC3643.sol";
import {IIdentityRegistry} from "../../src/registry/interfaces/IIdentityRegistry.sol";

/**
 * @title ERC3643AcceptanceImplTest
 * @notice T3.6: the six inherited ERC-3643 guarantees, unchanged, against the real suite
 *         (T1 + T2 + T4 + T4.3 + Token), wired as T5.1 wires it.
 */
contract ERC3643AcceptanceImplTest is ERC3643AcceptanceTest, M3System {
    function deploySystem() internal override {
        _deployM3();
        vm.prank(govOwner);
        tok.addAgent(agent);
        _onboardInvestor(alice, 586);
        _onboardInvestor(bob, 586);
        _onboardAsset(999.9e18 * 10);

        token = IERC3643(address(tok));
        registry = IIdentityRegistry(address(ir));
    }
}
