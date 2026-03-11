// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {ISanctionsOracle} from "../src/interfaces/ISanctionsOracle.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SanctionsOracleTest is Test {
    SanctionsOracle public oracle;
    address public admin = makeAddr("admin");
    address public manager = makeAddr("manager");
    address public user = makeAddr("user");
    address public sanctionedAddr = makeAddr("sanctioned");

    function setUp() public {
        oracle = new SanctionsOracle(admin);
    }

    // --- Constructor ---

    function test_constructor_grantsAdminRole() public view {
        assertTrue(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_constructor_grantsManagerRole() public view {
        assertTrue(oracle.hasRole(oracle.MANAGER_ROLE(), admin));
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert(SanctionsOracle.ZeroAddress.selector);
        new SanctionsOracle(address(0));
    }

    // --- addAddress ---

    function test_addAddress_setsIsSanctioned() public {
        vm.prank(admin);
        oracle.addAddress(sanctionedAddr);
        assertTrue(oracle.isSanctioned(sanctionedAddr));
    }

    function test_addAddress_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit ISanctionsOracle.AddressAdded(sanctionedAddr);
        oracle.addAddress(sanctionedAddr);
    }

    function test_addAddress_revertsIfAlreadySanctioned() public {
        vm.startPrank(admin);
        oracle.addAddress(sanctionedAddr);
        vm.expectRevert(abi.encodeWithSelector(SanctionsOracle.AlreadySanctioned.selector, sanctionedAddr));
        oracle.addAddress(sanctionedAddr);
        vm.stopPrank();
    }

    function test_addAddress_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(SanctionsOracle.ZeroAddress.selector);
        oracle.addAddress(address(0));
    }

    function test_addAddress_revertsWithoutManagerRole() public {
        bytes32 managerRole = oracle.MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, managerRole)
        );
        vm.prank(user);
        oracle.addAddress(sanctionedAddr);
    }

    // --- removeAddress ---

    function test_removeAddress_clearsIsSanctioned() public {
        vm.startPrank(admin);
        oracle.addAddress(sanctionedAddr);
        oracle.removeAddress(sanctionedAddr);
        vm.stopPrank();
        assertFalse(oracle.isSanctioned(sanctionedAddr));
    }

    function test_removeAddress_emitsEvent() public {
        vm.startPrank(admin);
        oracle.addAddress(sanctionedAddr);
        vm.expectEmit(true, false, false, false);
        emit ISanctionsOracle.AddressRemoved(sanctionedAddr);
        oracle.removeAddress(sanctionedAddr);
        vm.stopPrank();
    }

    function test_removeAddress_revertsIfNotSanctioned() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SanctionsOracle.NotSanctioned.selector, sanctionedAddr));
        oracle.removeAddress(sanctionedAddr);
    }

    function test_removeAddress_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(SanctionsOracle.ZeroAddress.selector);
        oracle.removeAddress(address(0));
    }

    // --- isSanctioned ---

    function test_isSanctioned_returnsFalseByDefault() public view {
        assertFalse(oracle.isSanctioned(user));
    }

    // --- Access control ---

    function test_adminCanGrantManagerRole() public {
        bytes32 managerRole = oracle.MANAGER_ROLE();
        vm.prank(admin);
        oracle.grantRole(managerRole, manager);
        assertTrue(oracle.hasRole(managerRole, manager));

        // Manager can now add addresses
        vm.prank(manager);
        oracle.addAddress(sanctionedAddr);
        assertTrue(oracle.isSanctioned(sanctionedAddr));
    }
}
