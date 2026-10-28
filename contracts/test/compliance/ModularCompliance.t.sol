// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ModularCompliance} from "../../src/compliance/ModularCompliance.sol";
import {IModularCompliance} from "../../src/compliance/interfaces/IModularCompliance.sol";
import {IModule} from "../../src/compliance/interfaces/IModule.sol";

/// @notice Test-only module with a settable verdict that counts its hooks.
contract ToggleModule is IModule {
    bool public verdict = true;
    uint256 public transfers;
    uint256 public mints;
    uint256 public burns;
    mapping(address => bool) public bound;

    function setVerdict(bool v) external {
        verdict = v;
    }

    function bindCompliance(address c) external {
        bound[c] = true;
        emit ComplianceBound(c);
    }

    function unbindCompliance(address c) external {
        bound[c] = false;
        emit ComplianceUnbound(c);
    }

    function moduleTransferAction(address, address, uint256) external {
        transfers++;
    }

    function moduleMintAction(address, uint256) external {
        mints++;
    }

    function moduleBurnAction(address, uint256) external {
        burns++;
    }

    function moduleCheck(address, address, uint256, address) external view returns (bool) {
        return verdict;
    }

    function isComplianceBound(address c) external view returns (bool) {
        return bound[c];
    }

    function canComplianceBind(address) external pure returns (bool) {
        return false;
    }

    function isPlugAndPlay() external pure virtual returns (bool) {
        return true;
    }

    function name() external pure returns (string memory) {
        return "ToggleModule";
    }

    function boom() external pure {
        revert("boom");
    }
}

/// @notice A module that is neither plug-and-play nor willing to bind.
contract NoBindModule is ToggleModule {
    function isPlugAndPlay() external pure override returns (bool) {
        return false;
    }
}

/**
 * @title ModularComplianceTest
 * @notice T2.1 base behaviour and T2.4 bind/unbind and multi-module veto fan-out.
 */
contract ModularComplianceTest is Test {
    ModularCompliance internal mc;
    ToggleModule internal m1;
    ToggleModule internal m2;
    address internal owner = makeAddr("owner");
    address internal token = makeAddr("token");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        mc = new ModularCompliance(owner);
        m1 = new ToggleModule();
        m2 = new ToggleModule();
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(ModularCompliance.ZeroAddress.selector);
        new ModularCompliance(address(0));
    }

    // ---------------------------------------------------------------- token binding

    function test_BindTokenByOwnerOnce() public {
        vm.expectEmit(false, false, false, true, address(mc));
        emit IModularCompliance.TokenBound(token);
        vm.prank(owner);
        mc.bindToken(token);
        assertEq(mc.getTokenBound(), token);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.TokenBindingRefused.selector, address(1)));
        mc.bindToken(address(1));
    }

    function test_BindTokenByTokenItself() public {
        vm.prank(token);
        mc.bindToken(token);
        assertEq(mc.getTokenBound(), token);
    }

    function test_BindTokenRefusesStrangerAndZero() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.TokenBindingRefused.selector, token));
        mc.bindToken(token);
        vm.prank(owner);
        vm.expectRevert(ModularCompliance.ZeroAddress.selector);
        mc.bindToken(address(0));
    }

    function test_UnbindToken() public {
        vm.prank(owner);
        mc.bindToken(token);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotComplianceOwner.selector, stranger));
        mc.unbindToken(token);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.TokenNotBoundHere.selector, stranger));
        mc.unbindToken(stranger);

        vm.expectEmit(false, false, false, true, address(mc));
        emit IModularCompliance.TokenUnbound(token);
        vm.prank(token);
        mc.unbindToken(token);
        assertEq(mc.getTokenBound(), address(0));
    }

    // ---------------------------------------------------------------- modules

    function test_AddAndRemoveModule() public {
        vm.expectEmit(true, false, false, false, address(mc));
        emit IModularCompliance.ModuleAdded(address(m1));
        vm.prank(owner);
        mc.addModule(address(m1));
        assertTrue(mc.isModuleBound(address(m1)));
        assertTrue(m1.bound(address(mc)));
        assertEq(mc.getModules().length, 1);

        vm.expectEmit(true, false, false, false, address(mc));
        emit IModularCompliance.ModuleRemoved(address(m1));
        vm.prank(owner);
        mc.removeModule(address(m1));
        assertFalse(mc.isModuleBound(address(m1)));
        assertFalse(m1.bound(address(mc)));
        assertEq(mc.getModules().length, 0);
    }

    function test_RemoveMiddleModuleKeepsOthers() public {
        ToggleModule m3 = new ToggleModule();
        vm.startPrank(owner);
        mc.addModule(address(m1));
        mc.addModule(address(m2));
        mc.addModule(address(m3));
        mc.removeModule(address(m1));
        vm.stopPrank();
        address[] memory mods = mc.getModules();
        assertEq(mods.length, 2);
        assertTrue(mc.isModuleBound(address(m2)) && mc.isModuleBound(address(m3)));
    }

    function test_AddModuleRejections() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotComplianceOwner.selector, stranger));
        mc.addModule(address(m1));

        vm.startPrank(owner);
        vm.expectRevert(ModularCompliance.ZeroAddress.selector);
        mc.addModule(address(0));
        mc.addModule(address(m1));
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.ModuleAlreadyBound.selector, address(m1)));
        mc.addModule(address(m1));

        NoBindModule nb = new NoBindModule();
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.ModuleCannotBind.selector, address(nb)));
        mc.addModule(address(nb));

        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.ModuleNotBound.selector, address(m2)));
        mc.removeModule(address(m2));
        vm.stopPrank();
    }

    function test_ModuleCapIs25() public {
        vm.startPrank(owner);
        for (uint256 i; i < 25; ++i) {
            mc.addModule(address(new ToggleModule()));
        }
        address extra = address(new ToggleModule());
        vm.expectRevert(ModularCompliance.TooManyModules.selector);
        mc.addModule(extra);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- canTransfer fan-out

    function test_NoModulesAllowsEverything() public view {
        assertTrue(mc.canTransfer(address(1), address(2), 3));
    }

    function test_AnySingleVetoRefuses() public {
        vm.startPrank(owner);
        mc.addModule(address(m1));
        mc.addModule(address(m2));
        vm.stopPrank();
        assertTrue(mc.canTransfer(address(1), address(2), 3));

        m2.setVerdict(false);
        assertFalse(mc.canTransfer(address(1), address(2), 3));
        m2.setVerdict(true);
        m1.setVerdict(false);
        assertFalse(mc.canTransfer(address(1), address(2), 3));

        vm.prank(owner);
        mc.removeModule(address(m1));
        assertTrue(mc.canTransfer(address(1), address(2), 3));
    }

    // ---------------------------------------------------------------- hooks

    function test_HooksFanOutAndAreTokenOnly() public {
        vm.startPrank(owner);
        mc.bindToken(token);
        mc.addModule(address(m1));
        mc.addModule(address(m2));
        vm.stopPrank();

        vm.startPrank(token);
        mc.transferred(address(1), address(2), 3);
        mc.created(address(2), 3);
        mc.destroyed(address(2), 3);
        vm.stopPrank();
        assertEq(m1.transfers() + m2.transfers(), 2);
        assertEq(m1.mints() + m2.mints(), 2);
        assertEq(m1.burns() + m2.burns(), 2);

        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotBoundToken.selector, stranger));
        mc.transferred(address(1), address(2), 3);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotBoundToken.selector, stranger));
        mc.created(address(2), 3);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotBoundToken.selector, stranger));
        mc.destroyed(address(2), 3);
        vm.stopPrank();
    }

    function test_HooksRefusedWithNoTokenBound() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotBoundToken.selector, address(0)));
        mc.created(address(2), 3);
    }

    // ---------------------------------------------------------------- callModuleFunction

    function test_CallModuleFunction() public {
        vm.prank(owner);
        mc.addModule(address(m1));

        bytes memory data = abi.encodeCall(ToggleModule.setVerdict, (false));
        vm.expectEmit(true, false, false, true, address(mc));
        emit IModularCompliance.ModuleInteraction(address(m1), ToggleModule.setVerdict.selector);
        vm.prank(owner);
        mc.callModuleFunction(data, address(m1));
        assertFalse(m1.verdict());

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ModularCompliance.ModuleCallFailed.selector,
                address(m1),
                abi.encodeWithSignature("Error(string)", "boom")
            )
        );
        mc.callModuleFunction(abi.encodeCall(ToggleModule.boom, ()), address(m1));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.ModuleNotBound.selector, address(m2)));
        mc.callModuleFunction(data, address(m2));

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ModularCompliance.NotComplianceOwner.selector, stranger));
        mc.callModuleFunction(data, address(m1));
    }
}
