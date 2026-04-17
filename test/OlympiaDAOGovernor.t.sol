// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaDAOGovernor} from "../src/OlympiaDAOGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {OlympiaDAOMemberNFT} from "../src/OlympiaDAOMemberNFT.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @dev Mock Treasury for integration testing
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

contract OlympiaDAOGovernorTest is Test {
    OlympiaDAOGovernor public governor;
    OlympiaDAOMemberNFT public nft;
    SanctionsOracle public oracle;
    TimelockController public timelock;
    OlympiaExecutor public executor;
    MockTreasury public treasury;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address payable public recipient = payable(makeAddr("recipient"));

    uint48 constant VOTING_DELAY = 1;
    uint32 constant VOTING_PERIOD = 100;
    uint256 constant QUORUM_PERCENT = 10;
    uint48 constant LATE_QUORUM_EXTENSION = 50;
    uint256 constant TIMELOCK_DELAY = 3600;

    function setUp() public {
        nft = new OlympiaDAOMemberNFT(
            "OlympiaDAO Member v0.4",
            "OLYMPIADAOv04",
            admin,
            0,           // inactivityThreshold disabled
            address(0)   // governor wired post-deploy
        );
        oracle = new SanctionsOracle(admin);
        treasury = new MockTreasury();
        vm.deal(address(treasury), 100 ether);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, admin);

        // OlympiaDAOGovernor — no sanctionsOracle constructor param
        governor = new OlympiaDAOGovernor(
            "OlympiaDAO Governor v0.4",
            IVotes(address(nft)),
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT,
            LATE_QUORUM_EXTENSION
        );

        executor = new OlympiaExecutor(address(treasury), address(timelock), address(oracle));

        vm.startPrank(admin);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        nft.safeMint(alice);   // tokenId 0
        nft.safeMint(bob);     // tokenId 1
        nft.safeMint(charlie); // tokenId 2
        vm.stopPrank();
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _proposeWithdrawal(address payable to, uint256 amount, string memory desc)
        internal
        returns (uint256 proposalId)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(executor);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaExecutor.executeTreasury, (to, amount));

        vm.prank(alice);
        proposalId = governor.propose(targets, values, calldatas, desc);
    }

    function _getProposalActions(address payable to, uint256 amount)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        targets[0] = address(executor);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaExecutor.executeTreasury, (to, amount));
    }

    function _advancePastVotingDelay() internal {
        vm.roll(block.number + VOTING_DELAY + 1);
    }

    function _advancePastVotingPeriod() internal {
        vm.roll(block.number + VOTING_PERIOD + 1);
    }

    function _advancePastTimelockDelay() internal {
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    function test_constructor_setsToken() public view {
        assertEq(address(governor.token()), address(nft));
    }

    function test_constructor_setsTimelock() public view {
        assertEq(governor.timelock(), address(timelock));
    }

    function test_constructor_setsSettings() public view {
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), 0);
    }

    // =========================================================================
    // Propose
    // =========================================================================

    function test_propose_happyPath() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Fund recipient");
        assertTrue(proposalId != 0);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function test_propose_sanctionedRecipient_succeeds() public {
        // OlympiaDAOGovernor has no sanctions check — sanctioned recipients pass through propose().
        // The sanctions gate is at ECFPRegistry.activateProposal() and OlympiaExecutor.executeTreasury().
        address sanctionedAddr = makeAddr("sanctioned");
        vm.prank(admin);
        oracle.addAddress(sanctionedAddr);

        address[] memory targets = new address[](1);
        targets[0] = address(executor);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaExecutor.executeTreasury, (payable(sanctionedAddr), 1 ether));

        // Should succeed — no sanctions gate in the Governor
        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Fund sanctioned");
        assertTrue(proposalId != 0);
    }

    // =========================================================================
    // Voting
    // =========================================================================

    function test_castVote_forAgainstAbstain() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Vote test");
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1); // For
        vm.prank(bob);
        governor.castVote(proposalId, 0); // Against
        vm.prank(charlie);
        governor.castVote(proposalId, 2); // Abstain

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 1);
        assertEq(againstVotes, 1);
        assertEq(abstainVotes, 1);
    }

    function test_castVote_onlyNFTHolders() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "NFT test");
        _advancePastVotingDelay();

        address noNFT = makeAddr("noNFT");
        vm.prank(noNFT);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 0);
    }

    function test_castVote_weightEqualsOnePerMember() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Weight test");
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 1);
    }

    // =========================================================================
    // Queue & Execute
    // =========================================================================

    function test_queue_succeedsAfterPassingVote() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Queue test");
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, 1 ether);
        governor.queue(targets, values, calldatas, keccak256(bytes("Queue test")));

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
    }

    function test_execute_succeedsAfterTimelockDelay() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Execute test");
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, 1 ether);
        governor.queue(targets, values, calldatas, keccak256(bytes("Execute test")));

        _advancePastTimelockDelay();

        uint256 balBefore = recipient.balance;
        governor.execute(targets, values, calldatas, keccak256(bytes("Execute test")));

        assertEq(recipient.balance, balBefore + 1 ether);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }

    // =========================================================================
    // Full Lifecycle
    // =========================================================================

    function test_fullLifecycle_proposeVoteQueueExecuteWithdraw() public {
        uint256 amount = 5 ether;
        uint256 proposalId = _proposeWithdrawal(recipient, amount, "Full lifecycle");

        _advancePastVotingDelay();
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);
        vm.prank(charlie);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, amount);
        governor.queue(targets, values, calldatas, keccak256(bytes("Full lifecycle")));

        _advancePastTimelockDelay();
        uint256 balBefore = recipient.balance;
        governor.execute(targets, values, calldatas, keccak256(bytes("Full lifecycle")));

        assertEq(recipient.balance, balBefore + amount);
    }

    // =========================================================================
    // Quorum
    // =========================================================================

    function test_quorum_correctFractionOfNFTSupply() public view {
        // 3 NFTs, 10% quorum = floor(3 × 10 / 100) = 0
        uint256 q = governor.quorum(block.number - 1);
        assertEq(q, 0);
    }

    function test_quorum_proposalFailsWithoutQuorum() public {
        vm.startPrank(admin);
        for (uint256 i = 0; i < 10; i++) {
            nft.safeMint(makeAddr(string(abi.encodePacked("voter", i))));
        }
        vm.stopPrank();

        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Quorum fail");
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 2); // Abstain

        _advancePastVotingPeriod();

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }
}
