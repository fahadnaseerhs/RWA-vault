// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

// T1.1 (ADR 0012, Fahad 2026-10-28): pulls Tokeny onchain-id v2.2.1 into the build so
// Foundry emits `Identity` and `ClaimIssuer` artifacts. Upstream pins `0.8.17`
// exactly and is compiled unmodified with that compiler; our own contracts stay on
// 0.8.26 and reach these through `src/identity/interfaces` (deployed via artifact).
import {Identity} from "@onchain-id/solidity/contracts/Identity.sol";
import {ClaimIssuer} from "@onchain-id/solidity/contracts/ClaimIssuer.sol";
