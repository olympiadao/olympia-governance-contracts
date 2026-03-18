// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";

contract ECFPRegistryTest is Test {
    ECFPRegistry public registry;

    address public admin = makeAddr("admin");
    address public governor = makeAddr("governor");
    address public alice = makeAddr("alice");
    address public recipient = makeAddr("recipient");

    bytes32 public ecfpId = keccak256("ECFP-001");
    uint256 public amount = 10 ether;
    bytes32 public metadataCID = keccak256("QmSomeIPFSHash");
    uint256 public constant MIN_REVIEW = 1 days;

    function setUp() public {
        registry = new ECFPRegistry(admin, MIN_REVIEW);

        // Grant GOVERNOR_ROLE to governor address
        vm.startPrank(admin);
        registry.grantRole(registry.GOVERNOR_ROLE(), governor);
        vm.stopPrank();
    }

    // --- Constructor ---

    function test_constructor_grantsRoles() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.GOVERNOR_ROLE(), admin));
    }

    function test_constructor_setsMinReviewPeriod() public view {
        assertEq(registry.minReviewPeriod(), MIN_REVIEW);
    }

    // --- submit ---

    function test_submit_createsProposal() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(p.ecfpId, ecfpId);
        assertEq(p.recipient, recipient);
        assertEq(p.amount, amount);
        assertEq(p.metadataCID, metadataCID);
        assertEq(p.proposer, alice);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Draft));
        assertGt(p.timestamp, 0);
    }

    function test_submit_emitsEvent() public {
        bytes32 expectedHash = registry.computeHashId(ecfpId, recipient, amount, metadataCID);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit ECFPRegistry.ProposalSubmitted(expectedHash, ecfpId, recipient, amount, metadataCID);
        registry.submit(ecfpId, recipient, amount, metadataCID);
    }

    function test_submit_revertsOnDuplicate() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ECFPRegistry.DuplicateProposal.selector, hashId));
        registry.submit(ecfpId, recipient, amount, metadataCID);
    }

    function test_submit_permissionless() public {
        address random = makeAddr("random");
        vm.prank(random);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);
        assertGt(uint256(hashId), 0);
    }

    function test_submit_permissionless_noNFT() public {
        // Any ETC address can submit, no NFT required
        address nonHolder = makeAddr("nonHolder");
        vm.prank(nonHolder);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(p.proposer, nonHolder);
    }

    // --- submit input validation (Fix 4: D14) ---

    function test_submit_revertsZeroRecipient() public {
        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.ZeroRecipient.selector);
        registry.submit(ecfpId, address(0), amount, metadataCID);
    }

    function test_submit_revertsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.ZeroAmount.selector);
        registry.submit(ecfpId, recipient, 0, metadataCID);
    }

    function test_submit_revertsEmptyMetadata() public {
        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.EmptyMetadata.selector);
        registry.submit(ecfpId, recipient, amount, bytes32(0));
    }

    function test_submit_revertsEmptyEcfpId() public {
        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.EmptyEcfpId.selector);
        registry.submit(bytes32(0), recipient, amount, metadataCID);
    }

    // --- computeHashId ---

    function test_computeHashId_matchesSubmit() public {
        bytes32 computed = registry.computeHashId(ecfpId, recipient, amount, metadataCID);

        vm.prank(alice);
        bytes32 submitted = registry.submit(ecfpId, recipient, amount, metadataCID);

        assertEq(computed, submitted);
    }

    function test_computeHashId_differentChainsDifferentHashes() public {
        bytes32 hash1 = registry.computeHashId(ecfpId, recipient, amount, metadataCID);

        vm.chainId(999);
        bytes32 hash2 = registry.computeHashId(ecfpId, recipient, amount, metadataCID);

        assertNotEq(hash1, hash2);
    }

    // --- getProposal ---

    function test_getProposal_returnsCorrectData() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(p.recipient, recipient);
        assertEq(p.amount, amount);
    }

    function test_getProposal_revertsForNonexistent() public {
        bytes32 fakeHash = keccak256("nonexistent");
        vm.expectRevert(abi.encodeWithSelector(ECFPRegistry.ProposalNotFound.selector, fakeHash));
        registry.getProposal(fakeHash);
    }

    // --- activateProposal ---

    function test_activateProposal_draftToActive() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);

        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ECFPRegistry.ProposalActivated(hashId);
        registry.activateProposal(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Active));
    }

    function test_activateProposal_revertsWithoutGovernorRole() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, registry.GOVERNOR_ROLE()
            )
        );
        vm.prank(alice);
        registry.activateProposal(hashId);
    }

    // --- Minimum review period (Fix 2: D11) ---

    function test_activateProposal_revertsBeforeReviewPeriod() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(governor);
        vm.expectRevert(ECFPRegistry.ReviewPeriodActive.selector);
        registry.activateProposal(hashId);
    }

    function test_activateProposal_succeedsAfterReviewPeriod() public {
        uint256 submitTime = block.timestamp;
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        // One second before deadline — should revert
        vm.warp(submitTime + MIN_REVIEW - 1);
        vm.prank(governor);
        vm.expectRevert(ECFPRegistry.ReviewPeriodActive.selector);
        registry.activateProposal(hashId);

        // Advance past the review period
        vm.warp(submitTime + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Active));
    }

    function test_activateProposal_zeroReviewPeriod() public {
        vm.prank(admin);
        ECFPRegistry zeroReview = new ECFPRegistry(admin, 0);

        vm.startPrank(admin);
        zeroReview.grantRole(zeroReview.GOVERNOR_ROLE(), governor);
        vm.stopPrank();

        vm.prank(alice);
        bytes32 hashId = zeroReview.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(governor);
        zeroReview.activateProposal(hashId);

        ECFPRegistry.Proposal memory p = zeroReview.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Active));
    }

    // --- approveProposal ---

    function test_approveProposal_activeToApproved() public {
        bytes32 hashId = _submitAndActivate();

        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ECFPRegistry.ProposalQueued(hashId);
        registry.approveProposal(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Approved));
    }

    // --- markExecuted (Fix 3: D12 — ecfpId in event) ---

    function test_markExecuted_approvedToExecuted() public {
        bytes32 hashId = _submitAndActivate();

        vm.startPrank(governor);
        registry.approveProposal(hashId);

        vm.expectEmit(true, true, false, true);
        emit ECFPRegistry.ProposalExecuted(uint256(ecfpId), hashId, recipient, amount, block.timestamp);
        registry.markExecuted(hashId);
        vm.stopPrank();

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Executed));
    }

    // --- invalidStatusTransition ---

    function test_invalidStatusTransition_draftToExecuted() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECFPRegistry.InvalidStatusTransition.selector,
                ECFPRegistry.ProposalStatus.Draft,
                ECFPRegistry.ProposalStatus.Executed
            )
        );
        registry.markExecuted(hashId);
    }

    function test_invalidStatusTransition_draftToApproved() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECFPRegistry.InvalidStatusTransition.selector,
                ECFPRegistry.ProposalStatus.Draft,
                ECFPRegistry.ProposalStatus.Approved
            )
        );
        registry.approveProposal(hashId);
    }

    // --- expireProposal ---

    function test_expireProposal_draftToExpired() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ECFPRegistry.ProposalExpired(hashId);
        registry.expireProposal(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Expired));
    }

    function test_expireProposal_activeToExpired() public {
        bytes32 hashId = _submitAndActivate();

        vm.prank(governor);
        registry.expireProposal(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Expired));
    }

    function test_expireProposal_revertsIfApproved() public {
        bytes32 hashId = _submitAndActivate();

        vm.startPrank(governor);
        registry.approveProposal(hashId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ECFPRegistry.InvalidStatusTransition.selector,
                ECFPRegistry.ProposalStatus.Approved,
                ECFPRegistry.ProposalStatus.Expired
            )
        );
        registry.expireProposal(hashId);
        vm.stopPrank();
    }

    // --- updateDraft (Fix 1: D10) ---

    function test_updateDraft_updatesFieldsNewHash() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        address newRecipient = makeAddr("newRecipient");
        uint256 newAmount = 20 ether;
        bytes32 newCID = keccak256("QmNewHash");

        vm.prank(alice);
        bytes32 newHashId = registry.updateDraft(hashId, newRecipient, newAmount, newCID);

        assertNotEq(hashId, newHashId);

        // Old entry Withdrawn
        ECFPRegistry.Proposal memory oldP = registry.getProposal(hashId);
        assertEq(uint8(oldP.status), uint8(ECFPRegistry.ProposalStatus.Withdrawn));

        // New entry Draft with updated fields
        ECFPRegistry.Proposal memory newP = registry.getProposal(newHashId);
        assertEq(newP.recipient, newRecipient);
        assertEq(newP.amount, newAmount);
        assertEq(newP.metadataCID, newCID);
        assertEq(uint8(newP.status), uint8(ECFPRegistry.ProposalStatus.Draft));
    }

    function test_updateDraft_sameHash_updatesInPlace() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(alice);
        bytes32 newHashId = registry.updateDraft(hashId, recipient, amount, metadataCID);

        assertEq(hashId, newHashId);
        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Draft));
    }

    function test_updateDraft_revertsNonSubmitter() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        address bob = makeAddr("bob");
        vm.prank(bob);
        vm.expectRevert(ECFPRegistry.NotSubmitter.selector);
        registry.updateDraft(hashId, recipient, 20 ether, metadataCID);
    }

    function test_updateDraft_revertsNonDraft() public {
        bytes32 hashId = _submitAndActivate();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECFPRegistry.InvalidStatusTransition.selector,
                ECFPRegistry.ProposalStatus.Active,
                ECFPRegistry.ProposalStatus.Draft
            )
        );
        registry.updateDraft(hashId, recipient, 20 ether, metadataCID);
    }

    function test_updateDraft_emitsEvent() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        address newRecipient = makeAddr("newRecipient");
        bytes32 expectedNewHash = registry.computeHashId(ecfpId, newRecipient, amount, metadataCID);

        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit ECFPRegistry.DraftUpdated(uint256(ecfpId), hashId, expectedNewHash);
        registry.updateDraft(hashId, newRecipient, amount, metadataCID);
    }

    function test_updateDraft_revalidatesInput() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.ZeroRecipient.selector);
        registry.updateDraft(hashId, address(0), amount, metadataCID);

        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.ZeroAmount.selector);
        registry.updateDraft(hashId, recipient, 0, metadataCID);

        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.EmptyMetadata.selector);
        registry.updateDraft(hashId, recipient, amount, bytes32(0));
    }

    // --- withdrawDraft (Fix 1: D10) ---

    function test_withdrawDraft_setsWithdrawnStatus() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit ECFPRegistry.DraftWithdrawn(uint256(ecfpId), hashId);
        registry.withdrawDraft(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Withdrawn));
    }

    function test_withdrawDraft_revertsNonSubmitter() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        address bob = makeAddr("bob");
        vm.prank(bob);
        vm.expectRevert(ECFPRegistry.NotSubmitter.selector);
        registry.withdrawDraft(hashId);
    }

    function test_withdrawDraft_revertsNonDraft() public {
        bytes32 hashId = _submitAndActivate();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECFPRegistry.InvalidStatusTransition.selector,
                ECFPRegistry.ProposalStatus.Active,
                ECFPRegistry.ProposalStatus.Withdrawn
            )
        );
        registry.withdrawDraft(hashId);
    }

    function test_withdrawDraft_cannotActivateWithdrawn() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(alice);
        registry.withdrawDraft(hashId);

        vm.warp(block.timestamp + MIN_REVIEW + 1);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ECFPRegistry.InvalidStatusTransition.selector,
                ECFPRegistry.ProposalStatus.Withdrawn,
                ECFPRegistry.ProposalStatus.Active
            )
        );
        registry.activateProposal(hashId);
    }

    // --- Admin can grant GOVERNOR_ROLE ---

    function test_adminCanGrantGovernorRole() public {
        address newGovernor = makeAddr("newGovernor");
        assertFalse(registry.hasRole(registry.GOVERNOR_ROLE(), newGovernor));

        vm.startPrank(admin);
        registry.grantRole(registry.GOVERNOR_ROLE(), newGovernor);
        vm.stopPrank();

        assertTrue(registry.hasRole(registry.GOVERNOR_ROLE(), newGovernor));
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _submitAndActivate() internal returns (bytes32 hashId) {
        vm.prank(alice);
        hashId = registry.submit(ecfpId, recipient, amount, metadataCID);
        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);
    }
}
