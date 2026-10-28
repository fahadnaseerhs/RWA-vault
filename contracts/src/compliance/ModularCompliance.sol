// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IModularCompliance} from "./interfaces/IModularCompliance.sol";
import {IModule} from "./interfaces/IModule.sol";

/**
 * @title ModularCompliance
 * @notice Binds one ERC-3643 token to a stack of transfer-rule modules and answers
 *         `canTransfer` as the AND of every module's `moduleCheck` (T2.1).
 * @dev Plain, immutable deployment (ADR 0025): the owner (2-of-3 multisig, ADR 0015) is
 *      fixed at construction. One token per compliance contract (ADR 0014, 0016). The
 *      state hooks are token-only and fan out to every module. Module count is capped so
 *      `canTransfer` stays bounded in gas, as in the T-REX reference.
 */
contract ModularCompliance is IModularCompliance {
    /// @notice Upper bound on bound modules, matching the T-REX reference implementation.
    uint256 public constant MAX_MODULES = 25;

    /// @notice The governance multisig. Fixed for the life of the contract.
    address public immutable owner;

    address private _token;
    address[] private _modules;
    mapping(address => bool) private _moduleBound;

    /// @notice An owner-only function was called by someone else.
    error NotComplianceOwner(address caller);
    /// @notice A token-only hook was called by an address other than the bound token.
    error NotBoundToken(address caller);
    /// @notice `bindToken` when a token is already bound, or by a caller that is neither owner nor that token.
    error TokenBindingRefused(address token);
    /// @notice `unbindToken` for a token that is not the bound one.
    error TokenNotBoundHere(address token);
    /// @notice An address argument was zero.
    error ZeroAddress();
    /// @notice `addModule` on a module already bound.
    error ModuleAlreadyBound(address module);
    /// @notice `removeModule` / `callModuleFunction` on a module that is not bound.
    error ModuleNotBound(address module);
    /// @notice `addModule` past {MAX_MODULES}.
    error TooManyModules();
    /// @notice A non-plug-and-play module refused to bind to this compliance.
    error ModuleCannotBind(address module);
    /// @notice A `callModuleFunction` call reverted; carries the module's revert data.
    error ModuleCallFailed(address module, bytes reason);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotComplianceOwner(msg.sender);
        _;
    }

    modifier onlyToken() {
        if (msg.sender != _token || msg.sender == address(0)) revert NotBoundToken(msg.sender);
        _;
    }

    /// @param owner_ the governance multisig; must not be `address(0)`.
    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
    }

    // ------------------------------------------------------------------
    // Token binding
    // ------------------------------------------------------------------

    /// @inheritdoc IModularCompliance
    /// @dev Callable once, by the owner or by the token itself (the token binds on `setCompliance`).
    function bindToken(address token_) external {
        if (token_ == address(0)) revert ZeroAddress();
        if (_token != address(0) || (msg.sender != owner && msg.sender != token_)) revert TokenBindingRefused(token_);
        _token = token_;
        emit TokenBound(token_);
    }

    /// @inheritdoc IModularCompliance
    function unbindToken(address token_) external {
        if (msg.sender != owner && msg.sender != _token) revert NotComplianceOwner(msg.sender);
        if (token_ != _token || token_ == address(0)) revert TokenNotBoundHere(token_);
        delete _token;
        emit TokenUnbound(token_);
    }

    // ------------------------------------------------------------------
    // Modules
    // ------------------------------------------------------------------

    /// @inheritdoc IModularCompliance
    function addModule(address module) external onlyOwner {
        if (module == address(0)) revert ZeroAddress();
        if (_moduleBound[module]) revert ModuleAlreadyBound(module);
        if (_modules.length >= MAX_MODULES) revert TooManyModules();
        IModule m = IModule(module);
        if (!m.isPlugAndPlay() && !m.canComplianceBind(address(this))) revert ModuleCannotBind(module);

        m.bindCompliance(address(this));
        _modules.push(module);
        _moduleBound[module] = true;
        emit ModuleAdded(module);
    }

    /// @inheritdoc IModularCompliance
    function removeModule(address module) external onlyOwner {
        if (!_moduleBound[module]) revert ModuleNotBound(module);
        IModule(module).unbindCompliance(address(this));

        uint256 n = _modules.length;
        for (uint256 i; i < n; ++i) {
            if (_modules[i] == module) {
                _modules[i] = _modules[n - 1];
                _modules.pop();
                break;
            }
        }
        delete _moduleBound[module];
        emit ModuleRemoved(module);
    }

    /// @inheritdoc IModularCompliance
    function callModuleFunction(bytes calldata callData, address module) external onlyOwner {
        if (!_moduleBound[module]) revert ModuleNotBound(module);
        (bool ok, bytes memory ret) = module.call(callData);
        if (!ok) revert ModuleCallFailed(module, ret);
        emit ModuleInteraction(module, bytes4(callData[:4]));
    }

    // ------------------------------------------------------------------
    // Token hooks
    // ------------------------------------------------------------------

    /// @inheritdoc IModularCompliance
    function transferred(address from, address to, uint256 amount) external onlyToken {
        uint256 n = _modules.length;
        for (uint256 i; i < n; ++i) {
            IModule(_modules[i]).moduleTransferAction(from, to, amount);
        }
    }

    /// @inheritdoc IModularCompliance
    function created(address to, uint256 amount) external onlyToken {
        uint256 n = _modules.length;
        for (uint256 i; i < n; ++i) {
            IModule(_modules[i]).moduleMintAction(to, amount);
        }
    }

    /// @inheritdoc IModularCompliance
    function destroyed(address from, uint256 amount) external onlyToken {
        uint256 n = _modules.length;
        for (uint256 i; i < n; ++i) {
            IModule(_modules[i]).moduleBurnAction(from, amount);
        }
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @inheritdoc IModularCompliance
    function canTransfer(address from, address to, uint256 amount) external view returns (bool) {
        uint256 n = _modules.length;
        for (uint256 i; i < n; ++i) {
            if (!IModule(_modules[i]).moduleCheck(from, to, amount, address(this))) return false;
        }
        return true;
    }

    /// @inheritdoc IModularCompliance
    function getModules() external view returns (address[] memory) {
        return _modules;
    }

    /// @inheritdoc IModularCompliance
    function getTokenBound() external view returns (address) {
        return _token;
    }

    /// @inheritdoc IModularCompliance
    function isModuleBound(address module) external view returns (bool) {
        return _moduleBound[module];
    }
}
