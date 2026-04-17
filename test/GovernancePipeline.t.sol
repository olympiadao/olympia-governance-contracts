// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaDAOGovernor} from "../src/OlympiaDAOGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {OlympiaDAOMemberNFT} from "../src/OlympiaDAOMemberNFT.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
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
    OlympiaDAOGovernor public governor;
    OlympiaDAOMemberNFT public nft;
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

        // Deploy timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, admin);

        // Deploy governor (pure OZ — no sanctionsOracle param)
        governor = new OlympiaDAOGovernor(
            "OlympiaDAO Governor v0.4",
            IVotes(address(nft)),
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT,
            LATE_QUORUM_EXTENSION
        );

        // Deploy executor (exit gate — checks sanctions before releasing funds)
        executor = new OlympiaExecutor(address(treasury), address(timelock), address(oracle));

        // Deploy ECFPRegistry (entry gate — checks sanctions at activateProposal)
        registry = new ECFPRegistry(admin, 0, type(uint256).max, 0, address(treasury), address(oracle));

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
    // Test 2: ECFPRegistry entry gate — sanctioned recipient blocked at activateProposal()
    // =========================================================================

    function test_pipeline_sanctionedRecipientBlockedAtRegistryGate() public {
        bytes32 ecfpId = keccak256("ECFP-SANCTIONED");
        bytes32 metadataCID = keccak256("QmSanctionedProposal");

        // Submit ECFP with sanctioned recipient — submit itself is permissionless
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, payable(sanctionedAddr), 1 ether, metadataCID);

        // activateProposal should revert because recipient is sanctioned
        vm.expectRevert(abi.encodeWithSelector(ECFPRegistry.SanctionedRecipient.selector, sanctionedAddr));
        vm.prank(admin);
        registry.activateProposal(hashId);
    }

    // =========================================================================
    // Test 3: ECFPRegistry cancelSanctioned — recipient sanctioned after activation
    // =========================================================================

    function test_pipeline_cancelSanctionedAfterActivation() public {
        bytes32 ecfpId = keccak256("ECFP-LATEWARN");
        bytes32 metadataCID = keccak256("QmLateWarnProposal");

        // Submit with a clean recipient
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, 2 ether, metadataCID);

        // Activate — recipient not yet sanctioned
        vm.prank(admin);
        registry.activateProposal(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Active));

        // Recipient becomes sanctioned after activation
        vm.prank(admin);
        oracle.addAddress(recipient);

        // Anyone can call cancelSanctioned
        vm.expectEmit(true, true, false, false);
        emit ECFPRegistry.ProposalCancelledDueToSanctions(hashId, recipient);
        registry.cancelSanctioned(hashId);

        // Verify ECFPRegistry status is Rejected
        p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Rejected));
    }

    function test_pipeline_cancelSanctioned_revertsWhenNotSanctioned() public {
        bytes32 ecfpId = keccak256("ECFP-CLEAN");
        bytes32 metadataCID = keccak256("QmCleanProposal");

        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, 1 ether, metadataCID);
        vm.prank(admin);
        registry.activateProposal(hashId);

        // Recipient is NOT sanctioned — should revert
        vm.expectRevert(abi.encodeWithSelector(ECFPRegistry.RecipientNotSanctioned.selector, hashId));
        registry.cancelSanctioned(hashId);
    }

    // =========================================================================
    // Test 4: Layer 3 — executor blocks sanctioned recipient at execution
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
    // Test 5: ECFPRegistry updateSanctionsOracle via governance
    // =========================================================================

    function test_pipeline_ecfpRegistryUpdatesSanctionsOracle() public {
        SanctionsOracle newOracle = new SanctionsOracle(admin);

        // Governance proposal to update the oracle on the ECFPRegistry
        address[] memory targets = new address[](1);
        targets[0] = address(registry);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(ECFPRegistry.updateSanctionsOracle, (address(newOracle)));

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Update ECFPRegistry oracle");

        _advancePastVotingDelay();
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        _advancePastVotingPeriod();
        governor.queue(targets, values, calldatas, keccak256(bytes("Update ECFPRegistry oracle")));
        _advancePastTimelockDelay();

        // Grant DEFAULT_ADMIN_ROLE to the timelock so it can call updateSanctionsOracle
        vm.startPrank(admin);
        registry.grantRole(registry.DEFAULT_ADMIN_ROLE(), address(timelock));
        vm.stopPrank();

        governor.execute(targets, values, calldatas, keccak256(bytes("Update ECFPRegistry oracle")));

        assertEq(address(registry.sanctionsOracle()), address(newOracle));
    }
}
