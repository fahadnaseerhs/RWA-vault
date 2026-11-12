// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IIdentity} from "../../src/vendor/onchain-id/interface/IIdentity.sol";
import {IIdentityRegistryStorage} from "../../src/registry/interfaces/IIdentityRegistryStorage.sol";
import {IdentityRegistryStorage} from "../../src/registry/IdentityRegistryStorage.sol";
import {MockIdentity} from "../mocks/MockIdentity.sol";

/**
 * @title IdentityRegistryStorageTest
 * @notice T1.5 storage-layer unit tests. The storage is shared across tokens (ADR 0016),
 *         so its access control is through bound registries rather than agent/owner.
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

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------

    function test_OwnerIsConstructorArgument() public view {
        assertEq(store.owner(), owner);
    }

    function test_ConstructorRejectsZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.InvalidOwner.selector, address(0)));
        new IdentityRegistryStorage(address(0));
    }

    // ------------------------------------------------------------------
    // Binding
    // ------------------------------------------------------------------

    function test_BindIdentityRegistry() public {
        address reg2 = makeAddr("registry-2");
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IIdentityRegistryStorage.IdentityRegistryBound(reg2);
        store.bindIdentityRegistry(reg2);

        address[] memory linked = store.linkedIdentityRegistries();
        assertEq(linked.length, 2, "should have 2 bound registries");
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
        vm.expectEmit(true, false, false, false);
        emit IIdentityRegistryStorage.IdentityRegistryUnbound(registryAddr);
        store.unbindIdentityRegistry(registryAddr);

        assertEq(store.linkedIdentityRegistries().length, 0, "should have 0 bound registries");
    }

    function test_UnbindNotBoundReverts() public {
        address notBound = makeAddr("not-bound");
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.RegistryNotBound.selector, notBound));
        store.unbindIdentityRegistry(notBound);
    }

    function test_OnlyOwnerCanBind() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, stranger));
        store.bindIdentityRegistry(makeAddr("x"));
    }

    function test_OnlyOwnerCanUnbind() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotOwner.selector, stranger));
        store.unbindIdentityRegistry(registryAddr);
    }

    // ------------------------------------------------------------------
    // Identity storage mutations
    // ------------------------------------------------------------------

    function test_AddIdentityToStorage() public {
        vm.prank(registryAddr);
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistryStorage.IdentityStored(walletAlice, IIdentity(address(identityAlice)));
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

    function test_AddNoCodeIdentityReverts() public {
        address noCode = makeAddr("no-code");
        vm.prank(registryAddr);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.IdentityHasNoCode.selector, noCode));
        store.addIdentityToStorage(walletAlice, IIdentity(noCode), COUNTRY_PK);
    }

    function test_RemoveIdentityFromStorage() public {
        vm.startPrank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistryStorage.IdentityUnstored(walletAlice, IIdentity(address(identityAlice)));
        store.removeIdentityFromStorage(walletAlice);
        vm.stopPrank();

        assertEq(address(store.storedIdentity(walletAlice)), address(0), "identity should be cleared");
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
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistryStorage.IdentityModified(IIdentity(address(identityAlice)), IIdentity(address(newId)));
        store.modifyStoredIdentity(walletAlice, IIdentity(address(newId)));
        vm.stopPrank();

        assertEq(address(store.storedIdentity(walletAlice)), address(newId));
    }

    function test_ModifyStoredCountry() public {
        vm.startPrank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
        vm.expectEmit(true, true, false, false);
        emit IIdentityRegistryStorage.CountryModified(walletAlice, 840);
        store.modifyStoredInvestorCountry(walletAlice, 840);
        vm.stopPrank();

        assertEq(store.storedInvestorCountry(walletAlice), 840);
    }

    // ------------------------------------------------------------------
    // Only bound registries can write
    // ------------------------------------------------------------------

    function test_OnlyBoundRegistryCanAdd() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, stranger));
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);
    }

    function test_OnlyBoundRegistryCanRemove() public {
        vm.prank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, stranger));
        store.removeIdentityFromStorage(walletAlice);
    }

    function test_OnlyBoundRegistryCanModifyIdentity() public {
        vm.prank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);

        MockIdentity newId = new MockIdentity();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, stranger));
        store.modifyStoredIdentity(walletAlice, IIdentity(address(newId)));
    }

    function test_OnlyBoundRegistryCanModifyCountry() public {
        vm.prank(registryAddr);
        store.addIdentityToStorage(walletAlice, IIdentity(address(identityAlice)), COUNTRY_PK);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistryStorage.NotBoundRegistry.selector, stranger));
        store.modifyStoredInvestorCountry(walletAlice, 840);
    }
}
