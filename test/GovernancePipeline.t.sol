// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaGovernor} from "../src/OlympiaGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";
import {ISanctionsOracle} from "../src/interfaces/ISanctionsOracle.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @dev Mock Treasury for end-to-end testing
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

/// @title GovernancePipelineTest
/// @notice End-to-end integration tests: ECFPRegistry + Governor + Executor + Treasury
contract GovernancePipelineTest is Test {
    OlympiaGovernor public governor;
    OlympiaMemberNFT public nft;
    SanctionsOracle public oracle;
    TimelockController public timelock;
    OlympiaExecutor public executor;
    ECFPRegistry public registry;
    MockTreasury public treasury;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address payable public recipient = payable(makeAddr("recipient"));
    address public sanctionedAddr = makeAddr("sanctioned");

    uint48 constant VOTING_DELAY = 1;
    uint32 constant VOTING_PERIOD = 100;
    uint256 constant QUORUM_PERCENT = 10;
    uint48 constant LATE_QUORUM_EXTENSION = 50;
    uint256 constant TIMELOCK_DELAY = 3600;

    function setUp() public {
        // Deploy infrastructure
        nft = new OlympiaMemberNFT(admin);
        oracle = new SanctionsOracle(admin);
        treasury = new MockTreasury();
        vm.deal(address(treasury), 100 ether);

        // Deploy timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, admin);

        // Deploy governor
        governor = new OlympiaGovernor(
            "OlympiaGovernor",
            nft,
            ISanctionsOracle(address(oracle)),
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT,
            LATE_QUORUM_EXTENSION
        );

        // Deploy executor
        executor = new OlympiaExecutor(address(treasury), address(timelock), address(oracle));

        // Deploy ECFPRegistry with admin
        registry = new ECFPRegistry(admin);

        // Configure roles
        vm.startPrank(admin);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Grant GOVERNOR_ROLE to the governor's timelock (execute path)
        registry.grantRole(registry.GOVERNOR_ROLE(), address(timelock));

        // Mint NFTs to voters
        nft.safeMint(alice); // tokenId 0
        nft.safeMint(bob); // tokenId 1
        nft.safeMint(charlie); // tokenId 2

        // Sanction an address
        oracle.addAddress(sanctionedAddr);
        vm.stopPrank();
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _advancePastVotingDelay() internal {
        vm.roll(block.number + VOTING_DELAY + 1);
    }

    function _advancePastVotingPeriod() internal {
        vm.roll(block.number + VOTING_PERIOD + 1);
    }

    function _advancePastTimelockDelay() internal {
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
    }

    function _getProposalActions(address payable to, uint256 amount)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        targets[0] = address(executor);
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaExecutor.executeTreasury, (to, amount));
    }

    // =========================================================================
    // Test 1: Full pipeline — ECFP submit → propose → vote → queue → execute → withdraw
    // =========================================================================

    function test_pipeline_fullLifecycleWithECFPRegistry() public {
        uint256 amount = 5 ether;
        bytes32 ecfpId = keccak256("ECFP-001");
        bytes32 metadataCID = keccak256("QmTestProposal");

        // Step 1: Submit ECFP (permissionless)
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        // Verify Draft status
        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Draft));

        // Step 2: Create Governor proposal
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, amount);

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Withdraw 5 ETH to recipient");

        // Step 3: Vote (advance past voting delay, then vote)
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1); // For
        vm.prank(bob);
        governor.castVote(proposalId, 1); // For

        // Step 4: Queue after voting period
        _advancePastVotingPeriod();
        governor.queue(targets, values, calldatas, keccak256(bytes("Withdraw 5 ETH to recipient")));

        // Step 5: Execute after timelock delay
        _advancePastTimelockDelay();

        uint256 recipientBalBefore = recipient.balance;
        governor.execute(targets, values, calldatas, keccak256(bytes("Withdraw 5 ETH to recipient")));

        // Verify funds arrived
        assertEq(recipient.balance, recipientBalBefore + amount);

        // Verify Governor proposal state is Executed
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    // =========================================================================
    // Test 2: Layer 1 — sanctioned recipient blocked at propose()
    // =========================================================================

    function test_pipeline_sanctionedRecipientBlockedAtLayer1() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(payable(sanctionedAddr), 1 ether);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OlympiaGovernor.SanctionedRecipient.selector, sanctionedAddr));
        governor.propose(targets, values, calldatas, "Send to sanctioned");
    }

    // =========================================================================
    // Test 3: Layer 2 — cancelIfSanctioned mid-vote
    // =========================================================================

    function test_pipeline_sanctionedRecipientCancelledAtLayer2() public {
        uint256 amount = 2 ether;

        // Propose to a clean recipient
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, amount);

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Withdraw 2 ETH");

        // Start voting
        _advancePastVotingDelay();
        vm.prank(alice);
        governor.castVote(proposalId, 1);

        // Recipient becomes sanctioned mid-vote
        vm.prank(admin);
        oracle.addAddress(recipient);

        // Anyone can cancel
        governor.cancelIfSanctioned(proposalId);

        // Verify cancelled
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    // =========================================================================
    // Test 4: Layer 3 — oracle updated after vote, executor blocks at execution
    // =========================================================================

    function test_pipeline_sanctionedRecipientBlockedAtLayer3() public {
        uint256 amount = 3 ether;

        // Full pipeline up to execution
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, amount);

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Withdraw 3 ETH");

        _advancePastVotingDelay();
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();
        governor.queue(targets, values, calldatas, keccak256(bytes("Withdraw 3 ETH")));

        _advancePastTimelockDelay();

        // Recipient becomes sanctioned AFTER queuing
        vm.prank(admin);
        oracle.addAddress(recipient);

        // Execute reverts because Executor's Layer 3 check catches it
        vm.expectRevert();
        governor.execute(targets, values, calldatas, keccak256(bytes("Withdraw 3 ETH")));
    }

    // =========================================================================
    // Test 5: Governor updates its own sanctions oracle via governance
    // =========================================================================

    function test_pipeline_governorUpdatesOwnSanctionsOracle() public {
        // Deploy a new oracle
        SanctionsOracle newOracle = new SanctionsOracle(admin);

        // Create governance proposal to update the oracle
        address[] memory targets = new address[](1);
        targets[0] = address(governor);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaGovernor.updateSanctionsOracle, (ISanctionsOracle(address(newOracle))));

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Update sanctions oracle");

        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();
        governor.queue(targets, values, calldatas, keccak256(bytes("Update sanctions oracle")));

        _advancePastTimelockDelay();
        governor.execute(targets, values, calldatas, keccak256(bytes("Update sanctions oracle")));

        // Verify oracle was updated
        assertEq(address(governor.sanctionsOracle()), address(newOracle));
    }
}
