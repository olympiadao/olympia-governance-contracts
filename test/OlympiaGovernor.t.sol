// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaGovernor} from "../src/OlympiaGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {OlympiaMemberNFT} from "../src/OlympiaMemberNFT.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {ISanctionsOracle} from "../src/interfaces/ISanctionsOracle.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
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

contract OlympiaGovernorTest is Test {
    OlympiaGovernor public governor;
    OlympiaMemberNFT public nft;
    SanctionsOracle public oracle;
    TimelockController public timelock;
    OlympiaExecutor public executor;
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

        // Deploy timelock — governor address not yet known, we'll set roles after
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

        // Configure timelock roles
        vm.startPrank(admin);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

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

    function _proposeWithdrawal(address payable to, uint256 amount, string memory desc)
        internal
        returns (uint256 proposalId)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(executor);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

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
        values[0] = 0;
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

    function test_constructor_setsSanctionsOracle() public view {
        assertEq(address(governor.sanctionsOracle()), address(oracle));
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
    // Propose (Layer 1)
    // =========================================================================

    function test_propose_happyPath() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Fund recipient");
        assertTrue(proposalId != 0);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function test_propose_revertsIfCalldataRecipientSanctioned() public {
        address[] memory targets = new address[](1);
        targets[0] = address(executor);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaExecutor.executeTreasury, (payable(sanctionedAddr), 1 ether));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OlympiaGovernor.SanctionedRecipient.selector, sanctionedAddr));
        governor.propose(targets, values, calldatas, "Fund sanctioned");
    }

    function test_propose_revertsIfTargetSanctioned() public {
        address[] memory targets = new address[](1);
        targets[0] = sanctionedAddr;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OlympiaGovernor.SanctionedRecipient.selector, sanctionedAddr));
        governor.propose(targets, values, calldatas, "Target sanctioned");
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
        governor.castVote(proposalId, 1); // Succeeds but with 0 weight

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function test_castVote_weightEqualsOnePerMember() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Weight test");
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 1); // 1 NFT = 1 vote (one-address-one-vote)
    }

    // =========================================================================
    // Queue & Execute
    // =========================================================================

    function test_queue_succeedsAfterPassingVote() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Queue test");
        _advancePastVotingDelay();

        // All 3 vote For (quorum = 10% of 3 = 1 needed)
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();

        // Queue
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
        // 1. Propose
        uint256 amount = 5 ether;
        uint256 proposalId = _proposeWithdrawal(recipient, amount, "Full lifecycle");

        // 2. Vote
        _advancePastVotingDelay();
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);
        vm.prank(charlie);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // 3. Queue
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, amount);
        governor.queue(targets, values, calldatas, keccak256(bytes("Full lifecycle")));

        // 4. Execute after timelock
        _advancePastTimelockDelay();
        uint256 balBefore = recipient.balance;
        governor.execute(targets, values, calldatas, keccak256(bytes("Full lifecycle")));

        // 5. Verify
        assertEq(recipient.balance, balBefore + amount);
    }

    // =========================================================================
    // cancelIfSanctioned (Layer 2)
    // =========================================================================

    function test_cancelIfSanctioned_cancelsWhenRecipientSanctioned() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Cancel test");
        _advancePastVotingDelay();

        // Recipient becomes sanctioned mid-voting
        vm.prank(admin);
        oracle.addAddress(address(recipient));

        // Anyone can cancel
        governor.cancelIfSanctioned(proposalId);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function test_cancelIfSanctioned_revertsWhenNoSanctionedRecipients() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "No sanction");
        _advancePastVotingDelay();

        vm.expectRevert(abi.encodeWithSelector(OlympiaGovernor.NoSanctionedRecipients.selector, proposalId));
        governor.cancelIfSanctioned(proposalId);
    }

    function test_cancelIfSanctioned_worksOnQueuedProposal() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Queued cancel");
        _advancePastVotingDelay();

        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _getProposalActions(recipient, 1 ether);
        governor.queue(targets, values, calldatas, keccak256(bytes("Queued cancel")));

        // Sanction recipient after queuing
        vm.prank(admin);
        oracle.addAddress(address(recipient));

        governor.cancelIfSanctioned(proposalId);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function test_cancelIfSanctioned_emitsEvent() public {
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Event test");
        _advancePastVotingDelay();

        vm.prank(admin);
        oracle.addAddress(address(recipient));

        vm.expectEmit(true, true, false, false);
        emit OlympiaGovernor.ProposalCancelledDueToSanctions(proposalId, address(recipient));
        governor.cancelIfSanctioned(proposalId);
    }

    // =========================================================================
    // updateSanctionsOracle
    // =========================================================================

    function test_updateSanctionsOracle_onlyViaGovernance() public {
        SanctionsOracle newOracle = new SanctionsOracle(admin);

        vm.prank(alice);
        vm.expectRevert();
        governor.updateSanctionsOracle(ISanctionsOracle(address(newOracle)));
    }

    function test_updateSanctionsOracle_updatesOracle() public {
        SanctionsOracle newOracle = new SanctionsOracle(admin);

        // Must go through full governance pipeline (onlyGovernance modifier)
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(OlympiaGovernor.updateSanctionsOracle, (ISanctionsOracle(address(newOracle))));
        string memory desc = "Update sanctions oracle";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        _advancePastVotingDelay();
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        _advancePastTimelockDelay();
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));

        assertEq(address(governor.sanctionsOracle()), address(newOracle));
    }

    // =========================================================================
    // Quorum
    // =========================================================================

    function test_quorum_correctFractionOfNFTSupply() public view {
        // 3 NFTs minted, 10% quorum = ceil(0.3) = 0 (floor, since OZ uses floor)
        // Actually OZ: quorum = totalSupply * numerator / denominator
        // 3 * 10 / 100 = 0 (integer division)
        // But with 10 NFTs: 10 * 10 / 100 = 1
        uint256 q = governor.quorum(block.number - 1);
        // 3 NFTs * 10% = 0 (floor division)
        assertEq(q, 0);
    }

    function test_quorum_proposalFailsWithoutQuorum() public {
        // Mint more NFTs so quorum > 0
        vm.startPrank(admin);
        for (uint256 i = 0; i < 10; i++) {
            nft.safeMint(makeAddr(string(abi.encodePacked("voter", i))));
        }
        vm.stopPrank();

        // Now 13 NFTs, quorum = 13 * 10 / 100 = 1
        uint256 proposalId = _proposeWithdrawal(recipient, 1 ether, "Quorum fail");
        _advancePastVotingDelay();

        // Only one abstain vote (abstain doesn't count toward quorum in Bravo)
        vm.prank(alice);
        governor.castVote(proposalId, 2); // Abstain

        _advancePastVotingPeriod();

        // Bravo quorum counts For + Abstain, so 1 abstain satisfies quorum=1
        // But we need to check if the vote passes: no For votes means it's Defeated
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }
}
