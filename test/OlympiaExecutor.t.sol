// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";

/// @dev Mock Treasury that accepts withdraw() calls and forwards ETH
contract MockTreasury {
    event Withdrawal(address indexed to, uint256 amount);

    function withdraw(address payable to, uint256 amount) external {
        require(amount <= address(this).balance, "MockTreasury: insufficient balance");
        (bool success,) = to.call{value: amount}("");
        require(success, "MockTreasury: transfer failed");
        emit Withdrawal(to, amount);
    }

    receive() external payable {}
}

/// @dev Mock Treasury that always reverts
contract RevertingTreasury {
    function withdraw(address payable, uint256) external pure {
        revert("RevertingTreasury: always reverts");
    }

    receive() external payable {}
}

contract OlympiaExecutorTest is Test {
    OlympiaExecutor public executor;
    MockTreasury public treasury;
    SanctionsOracle public oracle;

    address public admin = makeAddr("admin");
    address public timelockAddr = makeAddr("timelock");
    address payable public recipient = payable(makeAddr("recipient"));
    address public sanctionedAddr = makeAddr("sanctioned");

    function setUp() public {
        treasury = new MockTreasury();
        oracle = new SanctionsOracle(admin);
        executor = new OlympiaExecutor(address(treasury), timelockAddr, address(oracle));

        // Fund the mock treasury
        vm.deal(address(treasury), 100 ether);

        // Sanction an address for testing
        vm.prank(admin);
        oracle.addAddress(sanctionedAddr);
    }

    // --- Constructor ---

    function test_constructor_setsImmutables() public view {
        assertEq(executor.treasury(), address(treasury));
        assertEq(executor.timelock(), timelockAddr);
        assertEq(address(executor.sanctionsOracle()), address(oracle));
    }

    function test_constructor_revertsOnZeroTreasury() public {
        vm.expectRevert(OlympiaExecutor.ZeroAddress.selector);
        new OlympiaExecutor(address(0), timelockAddr, address(oracle));
    }

    function test_constructor_revertsOnZeroTimelock() public {
        vm.expectRevert(OlympiaExecutor.ZeroAddress.selector);
        new OlympiaExecutor(address(treasury), address(0), address(oracle));
    }

    function test_constructor_revertsOnZeroOracle() public {
        vm.expectRevert(OlympiaExecutor.ZeroAddress.selector);
        new OlympiaExecutor(address(treasury), timelockAddr, address(0));
    }

    // --- executeTreasury ---

    function test_executeTreasury_happyPath() public {
        uint256 amount = 1 ether;
        uint256 recipientBalBefore = recipient.balance;

        vm.prank(timelockAddr);
        executor.executeTreasury(recipient, amount);

        assertEq(recipient.balance, recipientBalBefore + amount);
    }

    function test_executeTreasury_revertsIfNotTimelock() public {
        vm.prank(makeAddr("random"));
        vm.expectRevert(OlympiaExecutor.OnlyTimelock.selector);
        executor.executeTreasury(recipient, 1 ether);
    }

    function test_executeTreasury_revertsIfRecipientSanctioned() public {
        vm.prank(timelockAddr);
        vm.expectRevert(abi.encodeWithSelector(OlympiaExecutor.SanctionedRecipient.selector, sanctionedAddr));
        executor.executeTreasury(payable(sanctionedAddr), 1 ether);
    }

    function test_executeTreasury_emitsEvent() public {
        uint256 amount = 2 ether;

        vm.prank(timelockAddr);
        vm.expectEmit(true, false, false, true);
        emit OlympiaExecutor.TreasuryExecution(recipient, amount);
        executor.executeTreasury(recipient, amount);
    }

    function test_executeTreasury_revertsIfTreasuryReverts() public {
        RevertingTreasury badTreasury = new RevertingTreasury();
        OlympiaExecutor badExecutor = new OlympiaExecutor(address(badTreasury), timelockAddr, address(oracle));

        vm.prank(timelockAddr);
        vm.expectRevert("RevertingTreasury: always reverts");
        badExecutor.executeTreasury(recipient, 1 ether);
    }
}
