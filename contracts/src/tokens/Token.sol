// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC3643} from "./interfaces/IERC3643.sol";
import {IIdentityRegistry} from "../registry/interfaces/IIdentityRegistry.sol";
import {IModularCompliance} from "../compliance/interfaces/IModularCompliance.sol";
import {IIdentity} from "../identity/interfaces/IIdentity.sol";
import {OwnerAgentRoles} from "../access/OwnerAgentRoles.sol";

/**
 * @title Token
 * @notice The ERC-3643 permissioned token for one asset (T3, ADR 0012, ADR 0016). 18 decimals,
 *         1 token = 1 fine gram (ADR 0020).
 * @dev Knows nothing about assets or the registry (ADR 0014): asset liveness, freshness and
 *      the reserve cap reach it only as a `canTransfer` refusal. `mint` calls `canTransfer`
 *      BEFORE `_mint` (T0.6 §18.2), which the mint-cap module relies on. Every holder movement
 *      goes through {_update}, so no entry point skips the checks; mint, burn, forced
 *      transfer and recovery set their own rules and bypass the holder checks. Deployed
 *      paused (T-REX); T5.1 unpauses as the last wiring step. Immutable (ADR 0025).
 *      `forcedTransfer` needs a schedule that has waited {FORCED_TRANSFER_DELAY}
 *      (ADR 0015); `recoveryAddress` is owner-only with no timelock (T3 spec §5).
 */
contract Token is ERC20, IERC3643, OwnerAgentRoles {
    /// @notice A forced transfer is publicly visible for this long before it can execute.
    uint64 public constant FORCED_TRANSFER_DELAY = 2 days;
    /// @notice Largest array any batch function accepts.
    uint256 public constant MAX_BATCH = 100;

    /// @notice Why a forced transfer was scheduled (emitted, ADR 0015).
    enum ForcedTransferReason {
        COURT_ORDER,
        REGULATORY_ACTION,
        ERRONEOUS_TRANSFER,
        LOST_KEY_RECOVERY
    }

    string private _tokenName;
    string private _tokenSymbol;
    address private _onchainID;
    IIdentityRegistry private _identityRegistry;
    IModularCompliance private _compliance;
    bool private _paused;
    mapping(address => bool) private _frozen;
    mapping(address => uint256) private _frozenTokens;
    mapping(bytes32 => uint64) private _forcedEta;
    /// @dev Set only for the duration of a forced move or a recovery, so {_update} skips holder checks.
    bool private _forcing;

    event ForcedTransferScheduled(
        bytes32 indexed id, address from, address to, uint256 amount, ForcedTransferReason reason, uint64 eta
    );
    event ForcedTransferCancelled(bytes32 indexed id);
    event ForcedTransferExecuted(bytes32 indexed id);

    error TokenPaused();
    error TokenAlreadyPaused();
    error TokenNotPaused();
    error WalletFrozen(address wallet);
    error InsufficientUnfrozenBalance(address wallet, uint256 available, uint256 requested);
    error ReceiverNotVerified(address wallet);
    error TransferNotCompliant(address from, address to, uint256 amount);
    error FreezeExceedsBalance(address wallet, uint256 balance, uint256 frozenAfter);
    error UnfreezeExceedsFrozen(address wallet, uint256 frozen, uint256 requested);
    error ArrayLengthMismatch();
    error BatchTooLarge(uint256 length);
    error ForcedTransferNotScheduled(bytes32 id);
    error ForcedTransferTimelocked(bytes32 id, uint64 eta);
    error ForcedTransferAlreadyScheduled(bytes32 id);
    error RecoveryIdentityMismatch(address lostWallet, address investorOnchainID);
    error RecoveryKeyNotOnIdentity(address newWallet);
    error NothingToRecover(address lostWallet);

    constructor(
        address owner_,
        address identityRegistry_,
        address compliance_,
        string memory name_,
        string memory symbol_,
        address onchainID_
    ) ERC20(name_, symbol_) OwnerAgentRoles(owner_) {
        if (identityRegistry_ == address(0) || compliance_ == address(0)) revert ZeroAddress();
        _tokenName = name_;
        _tokenSymbol = symbol_;
        _onchainID = onchainID_;
        _identityRegistry = IIdentityRegistry(identityRegistry_);
        _compliance = IModularCompliance(compliance_);
        _paused = true;
        IModularCompliance(compliance_).bindToken(address(this));
        emit UpdatedTokenInformation(name_, symbol_, 18, version(), onchainID_);
        emit IdentityRegistryAdded(identityRegistry_);
        emit ComplianceAdded(compliance_);
        emit Paused(msg.sender);
    }

    // ------------------------------------------------------------------
    // Metadata
    // ------------------------------------------------------------------

    function name() public view override(ERC20, IERC3643) returns (string memory) {
        return _tokenName;
    }

    function symbol() public view override(ERC20, IERC3643) returns (string memory) {
        return _tokenSymbol;
    }

    function decimals() public pure override(ERC20, IERC3643) returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC3643
    function version() public pure returns (string memory) {
        return "rwa-vault-3643-1.0.0";
    }

    /// @inheritdoc IERC3643
    function onchainID() external view returns (address) {
        return _onchainID;
    }

    /// @inheritdoc IERC3643
    function identityRegistry() external view returns (IIdentityRegistry) {
        return _identityRegistry;
    }

    /// @inheritdoc IERC3643
    function compliance() external view returns (IModularCompliance) {
        return _compliance;
    }

    /// @inheritdoc IERC3643
    function paused() external view returns (bool) {
        return _paused;
    }

    /// @inheritdoc IERC3643
    function isFrozen(address wallet) external view returns (bool) {
        return _frozen[wallet];
    }

    /// @inheritdoc IERC3643
    function getFrozenTokens(address wallet) external view returns (uint256) {
        return _frozenTokens[wallet];
    }

    /// @notice Earliest execution time of a scheduled forced transfer; 0 if none.
    function forcedTransferEta(address from, address to, uint256 amount) external view returns (uint64) {
        return _forcedEta[_forcedId(from, to, amount)];
    }

    // ------------------------------------------------------------------
    // Owner: configuration (ADR 0015)
    // ------------------------------------------------------------------

    /// @inheritdoc IERC3643
    function setName(string calldata name_) external onlyOwner {
        _tokenName = name_;
        emit UpdatedTokenInformation(name_, _tokenSymbol, 18, version(), _onchainID);
    }

    /// @inheritdoc IERC3643
    function setSymbol(string calldata symbol_) external onlyOwner {
        _tokenSymbol = symbol_;
        emit UpdatedTokenInformation(_tokenName, symbol_, 18, version(), _onchainID);
    }

    /// @inheritdoc IERC3643
    function setOnchainID(address onchainID_) external onlyOwner {
        _onchainID = onchainID_;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, 18, version(), onchainID_);
    }

    /// @inheritdoc IERC3643
    function setIdentityRegistry(address identityRegistry_) external onlyOwner {
        if (identityRegistry_ == address(0)) revert ZeroAddress();
        _identityRegistry = IIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(identityRegistry_);
    }

    /// @inheritdoc IERC3643
    /// @dev Unbinds from the old compliance and binds to the new one, as in T-REX.
    function setCompliance(address compliance_) external onlyOwner {
        if (compliance_ == address(0)) revert ZeroAddress();
        _compliance.unbindToken(address(this));
        _compliance = IModularCompliance(compliance_);
        IModularCompliance(compliance_).bindToken(address(this));
        emit ComplianceAdded(compliance_);
    }

    // ------------------------------------------------------------------
    // Agent: operations
    // ------------------------------------------------------------------

    /// @inheritdoc IERC3643
    function pause() external onlyAgent {
        if (_paused) revert TokenAlreadyPaused();
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @inheritdoc IERC3643
    function unpause() external onlyAgent {
        if (!_paused) revert TokenNotPaused();
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// @inheritdoc IERC3643
    function mint(address to, uint256 amount) public onlyAgent {
        if (!_identityRegistry.isVerified(to)) revert ReceiverNotVerified(to);
        // Compliance BEFORE _mint: the mint-cap module reads the pre-mint totalSupply (T0.6 §18.2).
        if (!_compliance.canTransfer(address(0), to, amount)) revert TransferNotCompliant(address(0), to, amount);
        _mint(to, amount);
        _compliance.created(to, amount);
    }

    /// @inheritdoc IERC3643
    function burn(address wallet, uint256 amount) public onlyAgent {
        _releaseShortfall(wallet, amount);
        _burn(wallet, amount);
        _compliance.destroyed(wallet, amount);
    }

    /// @inheritdoc IERC3643
    function setAddressFrozen(address wallet, bool freeze) public onlyAgent {
        _frozen[wallet] = freeze;
        emit AddressFrozen(wallet, freeze, msg.sender);
    }

    /// @inheritdoc IERC3643
    function freezePartialTokens(address wallet, uint256 amount) public onlyAgent {
        uint256 bal = balanceOf(wallet);
        uint256 after_ = _frozenTokens[wallet] + amount;
        if (after_ > bal) revert FreezeExceedsBalance(wallet, bal, after_);
        _frozenTokens[wallet] = after_;
        emit TokensFrozen(wallet, amount);
    }

    /// @inheritdoc IERC3643
    function unfreezePartialTokens(address wallet, uint256 amount) public onlyAgent {
        uint256 frozen = _frozenTokens[wallet];
        if (amount > frozen) revert UnfreezeExceedsFrozen(wallet, frozen, amount);
        _frozenTokens[wallet] = frozen - amount;
        emit TokensUnfrozen(wallet, amount);
    }

    // ------------------------------------------------------------------
    // Owner: forced transfer (ADR 0015, T3 spec §4) and recovery (§5)
    // ------------------------------------------------------------------

    /// @notice Schedules a forced transfer; it may execute after {FORCED_TRANSFER_DELAY}. Owner-only.
    function scheduleForcedTransfer(address from, address to, uint256 amount, ForcedTransferReason reason)
        external
        onlyOwner
    {
        bytes32 id = _forcedId(from, to, amount);
        if (_forcedEta[id] != 0) revert ForcedTransferAlreadyScheduled(id);
        uint64 eta = uint64(block.timestamp) + FORCED_TRANSFER_DELAY;
        _forcedEta[id] = eta;
        emit ForcedTransferScheduled(id, from, to, amount, reason, eta);
    }

    /// @notice Cancels a scheduled forced transfer. Owner-only.
    function cancelForcedTransfer(address from, address to, uint256 amount) external onlyOwner {
        bytes32 id = _forcedId(from, to, amount);
        if (_forcedEta[id] == 0) revert ForcedTransferNotScheduled(id);
        delete _forcedEta[id];
        emit ForcedTransferCancelled(id);
    }

    /// @inheritdoc IERC3643
    function forcedTransfer(address from, address to, uint256 amount) public onlyOwner returns (bool) {
        bytes32 id = _forcedId(from, to, amount);
        uint64 eta = _forcedEta[id];
        if (eta == 0) revert ForcedTransferNotScheduled(id);
        if (eta > block.timestamp) revert ForcedTransferTimelocked(id, eta);
        delete _forcedEta[id];
        if (!_identityRegistry.isVerified(to)) revert ReceiverNotVerified(to);

        _releaseShortfall(from, amount);
        _forcedMove(from, to, amount);
        _compliance.transferred(from, to, amount);
        emit ForcedTransferExecuted(id);
        return true;
    }

    /// @inheritdoc IERC3643
    function recoveryAddress(address lostWallet, address newWallet, address investorOnchainID)
        external
        onlyOwner
        returns (bool)
    {
        if (address(_identityRegistry.identity(lostWallet)) != investorOnchainID) {
            revert RecoveryIdentityMismatch(lostWallet, investorOnchainID);
        }
        if (!IIdentity(investorOnchainID).keyHasPurpose(keccak256(abi.encode(newWallet)), 1)) {
            revert RecoveryKeyNotOnIdentity(newWallet);
        }
        // A newWallet already in the registry must belong to the same investor (T3.3 VERIFY).
        if (
            _identityRegistry.contains(newWallet) && address(_identityRegistry.identity(newWallet)) != investorOnchainID
        ) {
            revert RecoveryIdentityMismatch(newWallet, investorOnchainID);
        }
        uint256 bal = balanceOf(lostWallet);
        if (bal == 0) revert NothingToRecover(lostWallet);

        uint256 frozenTokens = _frozenTokens[lostWallet];
        bool frozenFlag = _frozen[lostWallet];
        delete _frozenTokens[lostWallet];
        _forcedMove(lostWallet, newWallet, bal);
        _compliance.transferred(lostWallet, newWallet, bal);

        if (frozenTokens != 0) {
            _frozenTokens[newWallet] = _frozenTokens[newWallet] + frozenTokens;
            emit TokensUnfrozen(lostWallet, frozenTokens);
            emit TokensFrozen(newWallet, frozenTokens);
        }
        if (frozenFlag) {
            _frozen[newWallet] = true;
            emit AddressFrozen(newWallet, true, msg.sender);
        }

        if (!_identityRegistry.contains(newWallet)) {
            uint16 country = _identityRegistry.investorCountry(lostWallet);
            _identityRegistry.registerIdentity(newWallet, IIdentity(investorOnchainID), country);
        }
        _identityRegistry.deleteIdentity(lostWallet);
        emit RecoverySuccess(lostWallet, newWallet, investorOnchainID);
        return true;
    }

    // ------------------------------------------------------------------
    // Batches (T3.4): all-or-nothing, capped at MAX_BATCH
    // ------------------------------------------------------------------

    /// @inheritdoc IERC3643
    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external {
        _checkBatch(toList.length, amounts.length);
        for (uint256 i; i < toList.length; ++i) {
            _transfer(msg.sender, toList[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchForcedTransfer(address[] calldata fromList, address[] calldata toList, uint256[] calldata amounts)
        external
    {
        _checkBatch(fromList.length, toList.length);
        _checkBatch(fromList.length, amounts.length);
        for (uint256 i; i < fromList.length; ++i) {
            forcedTransfer(fromList[i], toList[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchMint(address[] calldata toList, uint256[] calldata amounts) external {
        _checkBatch(toList.length, amounts.length);
        for (uint256 i; i < toList.length; ++i) {
            mint(toList[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchBurn(address[] calldata wallets, uint256[] calldata amounts) external {
        _checkBatch(wallets.length, amounts.length);
        for (uint256 i; i < wallets.length; ++i) {
            burn(wallets[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchSetAddressFrozen(address[] calldata wallets, bool[] calldata freeze) external {
        _checkBatch(wallets.length, freeze.length);
        for (uint256 i; i < wallets.length; ++i) {
            setAddressFrozen(wallets[i], freeze[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchFreezePartialTokens(address[] calldata wallets, uint256[] calldata amounts) external {
        _checkBatch(wallets.length, amounts.length);
        for (uint256 i; i < wallets.length; ++i) {
            freezePartialTokens(wallets[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC3643
    function batchUnfreezePartialTokens(address[] calldata wallets, uint256[] calldata amounts) external {
        _checkBatch(wallets.length, amounts.length);
        for (uint256 i; i < wallets.length; ++i) {
            unfreezePartialTokens(wallets[i], amounts[i]);
        }
    }

    // ------------------------------------------------------------------
    // Internal
    // ------------------------------------------------------------------

    /**
     * @dev The single choke point for balances. Holder transfers (`from` and `to` both set,
     *      not forcing) are checked in the T3 spec §3 order and reported to compliance after
     *      the move. Mints and burns are checked by their entry points; forced moves skip
     *      holder checks by design. The sender's own verification is not re-checked (T-REX).
     */
    function _update(address from, address to, uint256 value) internal override {
        bool holderTransfer = from != address(0) && to != address(0) && !_forcing;
        if (holderTransfer) {
            if (_paused) revert TokenPaused();
            if (_frozen[from]) revert WalletFrozen(from);
            if (_frozen[to]) revert WalletFrozen(to);
            uint256 bal = balanceOf(from);
            uint256 frozen = _frozenTokens[from];
            uint256 available = bal > frozen ? bal - frozen : 0;
            if (value > available) revert InsufficientUnfrozenBalance(from, available, value);
            if (!_identityRegistry.isVerified(to)) revert ReceiverNotVerified(to);
            if (!_compliance.canTransfer(from, to, value)) revert TransferNotCompliant(from, to, value);
        }
        super._update(from, to, value);
        if (holderTransfer) _compliance.transferred(from, to, value);
    }

    function _forcedMove(address from, address to, uint256 amount) private {
        _forcing = true;
        _transfer(from, to, amount);
        _forcing = false;
    }

    /// @dev Unfreezes whatever part of `amount` exceeds the free balance (T-REX burn/forced rule).
    function _releaseShortfall(address wallet, uint256 amount) private {
        uint256 bal = balanceOf(wallet);
        uint256 frozen = _frozenTokens[wallet];
        uint256 free = bal > frozen ? bal - frozen : 0;
        if (amount > free) {
            uint256 release = amount - free;
            if (release > frozen) release = frozen;
            _frozenTokens[wallet] = frozen - release;
            emit TokensUnfrozen(wallet, release);
        }
    }

    function _checkBatch(uint256 a, uint256 b) private pure {
        if (a != b) revert ArrayLengthMismatch();
        if (a > MAX_BATCH) revert BatchTooLarge(a);
    }

    function _forcedId(address from, address to, uint256 amount) private pure returns (bytes32) {
        return keccak256(abi.encode(from, to, amount));
    }
}
