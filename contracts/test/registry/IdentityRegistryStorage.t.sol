// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IIdentity} from "../../src/vendor/onchain-id/interface/IIdentity.sol";
import {IdentityRegistryStorage} from "../../src/registry/IdentityRegistryStorage.sol";
import {MockIdentity} from "../mocks/MockIdentity.sol";

/**
 * @title IdentityRegistryStorageTest
 * @notice Storage-layer unit tests for the PR #5 `IdentityRegistryStorage` (Q29, Option 1).
 *         Access is through bound registries; binding and unbinding are owner-only (ADR 0015).
 */
contract IdentityRegistryStorageTest is Test {
    IdentityRegistryStorage internal store;
    address internal owner = makeAddr("owner (2-of-3 multisig)");
    address internal registryAddr = makeAddr("bound-registry");
    address internal stranger = makeAddr("stranger");
    address internal walletAlice = makeAddr("Alice");
    uint16 internal constant COUNTRY_PK = 586;

    MockIdentity internal identityAlice;

    function setUp() public {
        store = new IdentityRegistryStorage(owner);
        identityAlice = new MockIdentity();
        vm.prank(owner);
        store.bindIdentityRegistry(registryAddr);
    }

    // Constructor
    function test_OwnerIsConstructorArgument() public view {
        assertEq(store.owner(), owner);
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidOwner.selector, address(0)));
        new IdentityRegistryStorage(address(0));
    }

    // Binding
    function test_BindIdentityRegistry() public {
        assertEq(store.linkedIdentityRegistries().length, 1);
        assertEq(store.linkedIdentityRegistries()[0], registryAddr);
    }

    function test_BindDuplicateReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.RegistryAlreadyBound.selector, registryAddr));
        store.bindIdentityRegistry(registryAddr);
    }

    function test_BindZeroReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidRegistry.selector, address(0)));
        store.bindIdentityRegistry(address(0));
    }

    function test_UnbindIdentityRegistry() public {
        vm.prank(owner);
        store.unbindIdentityRegistry(registryAddr);
        assertEq(store.linkedIdentityRegistries().length, 0);
    }

    function test_UnbindNotBoundReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.RegistryNotBound.selector, stranger));
        store.unbindIdentityRegistry(stranger);
    }

    function test_OnlyOwnerCanBind() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, stranger));
        store.bindIdentityRegistry(makeAddr("other"));
    }

    function test_OnlyOwnerCanUnbind() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, stranger));
        store.unbindIdentityRegistry(registryAddr);
    }

    // Writes through a bound registry
    function test_AddIdentityToStorage() public {
        vm.prank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        assertEq(address(store.storedIdentity(walletAlice)), address(identityAlice));
        assertEq(store.storedInvestorCountry(walletAlice), COUNTRY_PK);
    }

    function test_AddDuplicateReverts() public {
        vm.startPrank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityAlreadyStored.selector, walletAlice));
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        vm.stopPrank();
    }

    function test_AddZeroWalletReverts() public {
        vm.prank(registryAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidWallet.selector, address(0)));
        store.addIdentityToStorage(address(0), IIdentity(address(identityAlice)), COUNTRY_PK);
    }

    function test_AddZeroIdentityReverts() public {
        vm.prank(registryAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidIdentity.selector, address(0)));
        store.addIdentityToStorage(walletAlice, IIdentity(address(0)), COUNTRY_PK);
    }

    function test_RemoveIdentityFromStorage() public {
        vm.startPrank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        store.removeIdentityFromStorage(walletAlice);
        vm.stopPrank();
        assertEq(address(store.storedIdentity(walletAlice)), address(0));
    }

    function test_RemoveNonExistentReverts() public {
        vm.prank(registryAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityNotStored.selector, walletAlice));
        store.removeIdentityFromStorage(walletAlice);
    }

    function test_ModifyStoredIdentity() public {
        MockIdentity newId = new MockIdentity();
        vm.startPrank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        store.modifyStoredIdentity(walletAlice, IIdentity(address(newId)));
        vm.stopPrank();
        assertEq(address(store.storedIdentity(walletAlice)), address(newId));
    }

    function test_ModifyStoredCountry() public {
        vm.startPrank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        store.modifyStoredInvestorCountry(walletAlice, 840);
        vm.stopPrank();
        assertEq(store.storedInvestorCountry(walletAlice), 840);
    }

    function test_ModifyUnstoredReverts() public {
        vm.prank(registryAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityNotStored.selector, walletAlice));
        store.modifyStoredInvestorCountry(walletAlice, 840);
    }

    function test_OnlyBoundRegistryCanAdd() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, stranger));
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
    }

    function test_OnlyBoundRegistryCanRemove() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, stranger));
        store.removeIdentityFromStorage(walletAlice);
    }

    function test_OnlyBoundRegistryCanModify() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, stranger));
        store.modifyStoredIdentity(walletAlice, IIdentity(address(identityAlice)));
    }
}
