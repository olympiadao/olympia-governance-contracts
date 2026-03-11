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

    function setUp() public {
        registry = new ECFPRegistry(admin);

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

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, registry.GOVERNOR_ROLE()
            )
        );
        vm.prank(alice);
        registry.activateProposal(hashId);
    }

    // --- approveProposal ---

    function test_approveProposal_activeToApproved() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.prank(governor);
        registry.activateProposal(hashId);

        vm.prank(governor);
        vm.expectEmit(true, false, false, false);
        emit ECFPRegistry.ProposalQueued(hashId);
        registry.approveProposal(hashId);

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Approved));
    }

    // --- markExecuted ---

    function test_markExecuted_approvedToExecuted() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.startPrank(governor);
        registry.activateProposal(hashId);
        registry.approveProposal(hashId);

        vm.expectEmit(true, false, false, true);
        emit ECFPRegistry.ProposalExecuted(hashId, recipient, amount, block.timestamp);
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
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.startPrank(governor);
        registry.activateProposal(hashId);
        registry.expireProposal(hashId);
        vm.stopPrank();

        ECFPRegistry.Proposal memory p = registry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Expired));
    }

    function test_expireProposal_revertsIfApproved() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit(ecfpId, recipient, amount, metadataCID);

        vm.startPrank(governor);
        registry.activateProposal(hashId);
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

    // --- Admin can grant GOVERNOR_ROLE ---

    function test_adminCanGrantGovernorRole() public {
        address newGovernor = makeAddr("newGovernor");
        assertFalse(registry.hasRole(registry.GOVERNOR_ROLE(), newGovernor));

        vm.startPrank(admin);
        registry.grantRole(registry.GOVERNOR_ROLE(), newGovernor);
        vm.stopPrank();

        assertTrue(registry.hasRole(registry.GOVERNOR_ROLE(), newGovernor));
    }
}
