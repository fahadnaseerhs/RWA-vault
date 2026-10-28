// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IModule} from "../interfaces/IModule.sol";
import {IModularCompliance} from "../interfaces/IModularCompliance.sol";
import {IAssetRegistry} from "../../registry/interfaces/IAssetRegistry.sol";

/**
 * @title AssetLiveModule
 * @notice Vetoes a mint unless the token's asset is LIVE, its reserve attestation is
 *         fresh, and the mint keeps `totalSupply <= reserve` (T2.2, ADR 0014, ADR 0019 §6,
 *         ADR 0021). Checks run in that order.
 * @dev Transfers and burns are never vetoed: a FROZEN or under-reserved asset blocks
 *      minting only. The module is stateless and plug-and-play; it resolves its asset
 *      through `registry.assetOfToken(compliance.getTokenBound())` (T0.6 §18.1), so an
 *      unbound token maps to `bytes32(0)`, which is never LIVE, and the mint fails closed.
 *      The supply cap relies on the token calling `canTransfer` BEFORE `_mint`
 *      (T0.6 §18.2, a T3.1 requirement): `totalSupply` here is the pre-mint supply.
 *      `moduleCheck` returns false and never reverts on a refused mint.
 */
contract AssetLiveModule is IModule {
    /// @notice The registry this module reads. Fixed at construction (ADR 0025).
    IAssetRegistry public immutable registry;

    mapping(address => bool) private _bound;

    /// @notice `bindCompliance` / `unbindCompliance` not called by the compliance itself.
    error OnlyCompliance(address caller);
    /// @notice `bindCompliance` on a compliance already bound.
    error ComplianceAlreadyBound(address compliance);
    /// @notice `unbindCompliance` or an action hook from a compliance that is not bound.
    error ComplianceNotBound(address compliance);
    /// @notice The registry address was zero.
    error ZeroRegistry();

    constructor(IAssetRegistry registry_) {
        if (address(registry_) == address(0)) revert ZeroRegistry();
        registry = registry_;
    }

    /// @inheritdoc IModule
    function bindCompliance(address compliance) external {
        if (msg.sender != compliance) revert OnlyCompliance(msg.sender);
        if (_bound[compliance]) revert ComplianceAlreadyBound(compliance);
        _bound[compliance] = true;
        emit ComplianceBound(compliance);
    }

    /// @inheritdoc IModule
    function unbindCompliance(address compliance) external {
        if (msg.sender != compliance) revert OnlyCompliance(msg.sender);
        if (!_bound[compliance]) revert ComplianceNotBound(compliance);
        delete _bound[compliance];
        emit ComplianceUnbound(compliance);
    }

    /// @inheritdoc IModule
    function moduleTransferAction(address, address, uint256) external view {
        if (!_bound[msg.sender]) revert ComplianceNotBound(msg.sender);
    }

    /// @inheritdoc IModule
    function moduleMintAction(address, uint256) external view {
        if (!_bound[msg.sender]) revert ComplianceNotBound(msg.sender);
    }

    /// @inheritdoc IModule
    function moduleBurnAction(address, uint256) external view {
        if (!_bound[msg.sender]) revert ComplianceNotBound(msg.sender);
    }

    /// @inheritdoc IModule
    function moduleCheck(address from, address, uint256 value, address compliance) external view returns (bool) {
        if (from != address(0)) return true; // transfers and burns pass (ADR 0019 §6)

        address token = IModularCompliance(compliance).getTokenBound();
        if (token == address(0)) return false;
        bytes32 assetId = registry.assetOfToken(token);
        if (!registry.isLive(assetId)) return false;

        // ADR 0021: a stale reserve blocks minting. Age == window passes; a zero window never does.
        uint64 ts = registry.valuationTsOf(assetId);
        uint64 window = registry.valuationWindowOf(assetId);
        if (window == 0 || ts > block.timestamp || block.timestamp - ts > window) return false;

        uint256 reserve = registry.reserveOf(assetId);
        uint256 supply = IERC20(token).totalSupply();
        // supply + value <= reserve, written so it cannot overflow.
        return supply <= reserve && value <= reserve - supply;
    }

    /// @inheritdoc IModule
    function isComplianceBound(address compliance) external view returns (bool) {
        return _bound[compliance];
    }

    /// @inheritdoc IModule
    function canComplianceBind(address) external pure returns (bool) {
        return true;
    }

    /// @inheritdoc IModule
    function isPlugAndPlay() external pure returns (bool) {
        return true;
    }

    /// @inheritdoc IModule
    function name() external pure returns (string memory) {
        return "AssetLiveModule";
    }
}
