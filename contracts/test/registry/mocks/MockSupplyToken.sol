// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/// @notice Test-only token exposing a settable `totalSupply`, for registry supply derivation tests.
contract MockSupplyToken {
    uint256 public totalSupply;

    function setTotalSupply(uint256 s) external {
        totalSupply = s;
    }
}
