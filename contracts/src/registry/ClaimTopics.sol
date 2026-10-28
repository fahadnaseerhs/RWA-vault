// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

/**
 * @dev The single claim topic MS1 requires of every holder (Q02 = A, T1 spec §4). One value
 *      shared by the deploy script, tests and the console. The registry never hard-wires it:
 *      the deploy script seeds it.
 */
uint256 constant KYC_TOPIC = 1;
