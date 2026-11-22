// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IReserveAttestationSource} from "../../../src/registry/interfaces/IReserveAttestationSource.sol";

/**
 * @title MockAttestationSource
 * @notice Test-only {IReserveAttestationSource} whose attestations are set directly.
 * @dev Clause 1 (signature) is out of scope here: the real MS1 source verifies it at
 *      submit time (ADR 0017, 0027). `set` may key an attestation under a different id
 *      than it carries, so tests can reach `AssetIdMismatch`.
 */
contract MockAttestationSource is IReserveAttestationSource {
    mapping(bytes32 => ReserveAttestation) private _latest;
    mapping(bytes32 => bool) private _has;

    function set(bytes32 key, ReserveAttestation memory a) external {
        _latest[key] = a;
        _has[key] = true;
    }

    function latest(bytes32 assetId) external view returns (ReserveAttestation memory) {
        return _latest[assetId];
    }

    function hasAttestation(bytes32 assetId) external view returns (bool) {
        return _has[assetId];
    }
}
