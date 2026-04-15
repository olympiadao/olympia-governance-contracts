// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";

/// @title ECFPRegistrySpamTest
/// @notice Spam protection tests for demo_v0.4: submission bond, draft cap, pull refunds, batch expiry.
///         See docs/ATTRIBUTION.md for design pattern attributions (TCR, EIP-1559, OZ Pull Payment).
contract ECFPRegistrySpamTest is Test {
    ECFPRegistry public registry;

    // Standard test addresses
    address public admin = makeAddr("admin");
    address public governor = makeAddr("governor");
    address public alice = makeAddr("alice");
    address public attacker = makeAddr("attacker");
    address public recipient = makeAddr("recipient");

    // Treasury receives slashed bonds
    address payable public treasury;

    // Registry parameters
    uint256 public constant BOND = 1 ether;
    uint256 public constant MAX_DRAFTS = 3;
    uint256 public constant MIN_REVIEW = 300; // 5 minutes

    // Proposal fields
    bytes32 public ecfpId1 = keccak256("ECFP-001");
    bytes32 public ecfpId2 = keccak256("ECFP-002");
    bytes32 public ecfpId3 = keccak256("ECFP-003");
    bytes32 public ecfpId4 = keccak256("ECFP-004");
    bytes32 public metadataCID = keccak256("QmSomeIPFSHash");
    uint256 public amount = 1000 ether;

    function setUp() public {
        // Treasury is a plain address that accepts ETH (like OlympiaTreasury receive())
        treasury = payable(makeAddr("treasury"));
        vm.deal(treasury, 0);

        registry = new ECFPRegistry(admin, MIN_REVIEW, MAX_DRAFTS, BOND, treasury);

        vm.startPrank(admin);
        registry.grantRole(registry.GOVERNOR_ROLE(), governor);
        vm.stopPrank();

        // Fund test wallets for bond payments
        vm.deal(alice, 100 ether);
        vm.deal(attacker, 100 ether);
    }

    // ========================================================================
    // 1. Happy Path — Legitimate Proposal Lifecycle
    // ========================================================================

    function test_happyPath_submitAndActivate_bondRefunded() public {
        // Submit with correct bond
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        assertEq(registry.bondOf(hashId), BOND, "bond held");
        assertEq(registry.activeDraftCount(alice), 1, "count incremented");

        // Warp past review period and activate
        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);

        // Bond queued for refund, count decremented
        assertEq(registry.bondOf(hashId), 0, "bond cleared");
        assertEq(registry.pendingRefunds(alice), BOND, "refund pending");
        assertEq(registry.activeDraftCount(alice), 0, "count decremented");

        // Alice claims refund
        uint256 balBefore = alice.balance;
        vm.prank(alice);
        registry.claimRefund();

        assertEq(alice.balance, balBefore + BOND, "bond returned");
        assertEq(registry.pendingRefunds(alice), 0, "refund cleared");
    }

    function test_happyPath_bondZeroAtSubmit_returnedOnActivate() public {
        // If submissionBond is 0, no ETH required; no refund on activate
        vm.prank(admin);
        registry.setSubmissionBond(0);

        vm.prank(alice);
        bytes32 hashId = registry.submit{value: 0}(ecfpId1, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);

        // pendingRefunds stays 0 — no bond to return
        assertEq(registry.pendingRefunds(alice), 0);
    }

    function test_happyPath_withdrawDraft_bondRefunded() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        uint256 balBefore = alice.balance;

        // Voluntary cleanup — bond returned, no slash
        vm.prank(alice);
        registry.withdrawDraft(hashId);

        assertEq(registry.activeDraftCount(alice), 0, "count decremented on withdraw");
        assertEq(registry.pendingRefunds(alice), BOND, "refund pending after withdraw");

        vm.prank(alice);
        registry.claimRefund();
        assertEq(alice.balance, balBefore + BOND, "bond returned on withdraw");
    }

    function test_happyPath_updateDraft_bondMigratedToNewHashId() public {
        vm.prank(alice);
        bytes32 oldHashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);
        assertEq(registry.bondOf(oldHashId), BOND);

        // Update changes metadataCID → new hashId
        bytes32 newMeta = keccak256("QmNewMetadata");
        vm.prank(alice);
        bytes32 newHashId = registry.updateDraft(oldHashId, recipient, amount, newMeta);

        assertNotEq(newHashId, oldHashId, "hashId changed");
        assertEq(registry.bondOf(oldHashId), 0, "old bond cleared");
        assertEq(registry.bondOf(newHashId), BOND, "bond migrated to new hashId");
        assertEq(registry.activeDraftCount(alice), 1, "count unchanged after update");
    }

    function test_happyPath_updateDraft_sameHashId_bondUnchanged() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        // Update with same fields — hashId unchanged
        vm.prank(alice);
        bytes32 sameHashId = registry.updateDraft(hashId, recipient, amount, metadataCID);

        assertEq(sameHashId, hashId, "hashId unchanged");
        assertEq(registry.bondOf(hashId), BOND, "bond unchanged");
        assertEq(registry.activeDraftCount(alice), 1, "count unchanged");
    }

    function test_happyPath_multipleRefundsAccumulate() public {
        // Alice submits two proposals, both activated — bonds accumulate in pendingRefunds
        bytes32 hashId1 = _submitWithBond(alice, ecfpId1, 1 * BOND);
        bytes32 hashId2 = _submitWithBond(alice, ecfpId2, 1 * BOND);

        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId1);
        vm.prank(governor);
        registry.activateProposal(hashId2);

        assertEq(registry.pendingRefunds(alice), 2 * BOND, "both bonds queued");

        uint256 balBefore = alice.balance;
        vm.prank(alice);
        registry.claimRefund();
        assertEq(alice.balance, balBefore + 2 * BOND, "both bonds claimed at once");
    }

    // ========================================================================
    // 2. Spam Flooding Attack — Single Address
    // ========================================================================

    function test_spam_capEnforcedAtMaxDrafts() public {
        // Submit up to the cap — all succeed
        _submitWithBond(attacker, ecfpId1, BOND);
        _submitWithBond(attacker, ecfpId2, BOND);
        _submitWithBond(attacker, ecfpId3, BOND);
        assertEq(registry.activeDraftCount(attacker), MAX_DRAFTS);

        // 4th submission reverts
        bytes32 ecfpId4_ = keccak256("ECFP-SPAM-4");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(ECFPRegistry.TooManyActiveDrafts.selector, attacker, MAX_DRAFTS));
        registry.submit{value: BOND}(ecfpId4_, recipient, amount, keccak256("QmSpam4"));
    }

    function test_spam_batchExpire_singleTx_bondsToTreasury() public {
        bytes32 h1 = _submitWithBond(attacker, ecfpId1, BOND);
        bytes32 h2 = _submitWithBond(attacker, ecfpId2, BOND);
        bytes32 h3 = _submitWithBond(attacker, ecfpId3, BOND);

        assertEq(address(registry).balance, 3 * BOND);

        bytes32[] memory hashIds = new bytes32[](3);
        hashIds[0] = h1;
        hashIds[1] = h2;
        hashIds[2] = h3;

        vm.prank(governor);
        registry.batchExpire(hashIds);

        // All bonds forwarded to treasury
        assertEq(treasury.balance, 3 * BOND, "treasury received slashed bonds");
        assertEq(address(registry).balance, 0, "registry balance zero");
        assertEq(registry.activeDraftCount(attacker), 0, "count reset after batch expiry");
    }

    function test_spam_afterBatchExpire_attackerCanResubmit() public {
        // Cap is not a permanent ban — just a concurrency limit
        bytes32 h1 = _submitWithBond(attacker, ecfpId1, BOND);
        bytes32 h2 = _submitWithBond(attacker, ecfpId2, BOND);
        bytes32 h3 = _submitWithBond(attacker, ecfpId3, BOND);

        bytes32[] memory hashIds = new bytes32[](3);
        hashIds[0] = h1;
        hashIds[1] = h2;
        hashIds[2] = h3;

        vm.prank(governor);
        registry.batchExpire(hashIds);

        // Attacker can now submit again (but loses another 1 ETC per attempt)
        assertEq(registry.activeDraftCount(attacker), 0);
        _submitWithBond(attacker, keccak256("ECFP-AGAIN"), BOND);
        assertEq(registry.activeDraftCount(attacker), 1);
    }

    // ========================================================================
    // 3. Multi-Wallet Flood
    // ========================================================================

    function test_spam_multiWalletFlood_batchExpireAll() public {
        uint256 numAttackers = 5;
        uint256 proposalsPerAttacker = MAX_DRAFTS;
        bytes32[] memory allHashIds = new bytes32[](numAttackers * proposalsPerAttacker);

        uint256 idx = 0;
        for (uint256 i = 0; i < numAttackers; i++) {
            address attackerAddr = makeAddr(string(abi.encodePacked("attacker", i)));
            vm.deal(attackerAddr, 10 ether);

            for (uint256 j = 0; j < proposalsPerAttacker; j++) {
                bytes32 eid = keccak256(abi.encodePacked("ecfp", i, j));
                bytes32 meta = keccak256(abi.encodePacked("meta", i, j));
                vm.prank(attackerAddr);
                allHashIds[idx] = registry.submit{value: BOND}(eid, recipient, amount, meta);
                idx++;
            }
        }

        uint256 totalBond = numAttackers * proposalsPerAttacker * BOND;
        assertEq(address(registry).balance, totalBond, "all bonds held");

        // GOVERNOR_ROLE sweeps all in one tx
        vm.prank(governor);
        registry.batchExpire(allHashIds);

        assertEq(treasury.balance, totalBond, "all bonds to treasury");
        assertEq(address(registry).balance, 0);
    }

    // ========================================================================
    // 4. Quality Rejection — Low-Quality Single Submission
    // ========================================================================

    function test_quality_lowQualityExpired_bondSlashed() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        uint256 treasuryBefore = treasury.balance;

        // GOVERNOR_ROLE expires a single low-quality proposal
        vm.prank(governor);
        registry.expireProposal(hashId);

        assertEq(treasury.balance, treasuryBefore + BOND, "bond slashed to treasury");
        assertEq(registry.pendingRefunds(alice), 0, "no refund on slash");
        assertEq(registry.activeDraftCount(alice), 0, "count decremented");
    }

    function test_quality_fraudulentProposal_bondSlashed() public {
        // Same mechanism — fraud and spam treated identically
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        vm.prank(governor);
        registry.expireProposal(hashId);

        // Bond slashed, proposer has no refund
        assertEq(registry.pendingRefunds(alice), 0);
        assertEq(treasury.balance, BOND);
    }

    function test_quality_afterSlash_proposerCanResubmit() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        vm.prank(governor);
        registry.expireProposal(hashId);

        // Can try again (with improved submission)
        assertEq(registry.activeDraftCount(alice), 0);
        _submitWithBond(alice, ecfpId2, BOND);
        assertEq(registry.activeDraftCount(alice), 1);
    }

    // ========================================================================
    // 5. Active Expiry — No Bond Transfer (bond already returned at activation)
    // ========================================================================

    function test_expiry_activeProposal_noBondTransfer() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);

        // Bond was already refunded at activation
        assertEq(registry.pendingRefunds(alice), BOND);
        uint256 treasuryBefore = treasury.balance;

        // Expire the Active proposal — no additional bond transfer
        vm.prank(governor);
        registry.expireProposal(hashId);

        assertEq(treasury.balance, treasuryBefore, "treasury unchanged: bond already returned at activate");
        assertEq(registry.pendingRefunds(alice), BOND, "refund still pending (not slashed)");
        // Count was already decremented at activate — no double decrement
        assertEq(registry.activeDraftCount(alice), 0);
    }

    // ========================================================================
    // 6. Bond Mechanics — Edge Cases
    // ========================================================================

    function test_bond_incorrectValue_reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ECFPRegistry.IncorrectBond.selector, BOND, BOND - 1));
        registry.submit{value: BOND - 1}(ecfpId1, recipient, amount, metadataCID);
    }

    function test_bond_excessValue_reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ECFPRegistry.IncorrectBond.selector, BOND, BOND + 1));
        registry.submit{value: BOND + 1}(ecfpId1, recipient, amount, metadataCID);
    }

    function test_bond_exactValue_succeeds() public {
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);
        assertEq(registry.bondOf(hashId), BOND);
    }

    function test_bond_claimRefund_noBalance_reverts() public {
        vm.prank(alice);
        vm.expectRevert(ECFPRegistry.NoRefundPending.selector);
        registry.claimRefund();
    }

    // ========================================================================
    // 7. Economic Attack — Bond Administration
    // ========================================================================

    function test_bond_setSubmissionBond_onlyAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, registry.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(attacker);
        registry.setSubmissionBond(0);
    }

    function test_bond_setSubmissionBond_adminSucceeds_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit ECFPRegistry.SubmissionBondUpdated(BOND, 0);
        registry.setSubmissionBond(0);
        assertEq(registry.submissionBond(), 0);
    }

    function test_bond_setSubmissionBond_existingBondsUnaffected() public {
        // Submit at 1 ETC bond
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);
        assertEq(registry.bondOf(hashId), BOND);

        // Admin reduces bond for future submissions
        vm.prank(admin);
        registry.setSubmissionBond(0.1 ether);

        // Existing proposal's bond is unchanged
        assertEq(registry.bondOf(hashId), BOND, "existing bond stored at submit-time value");
    }

    function test_bond_frontrunBondReduction_attackerCannotReduceOwnBond() public {
        // Attacker submits, then tries to reduce their bond liability — cannot
        vm.prank(attacker);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        // Only DEFAULT_ADMIN_ROLE can change bond
        vm.prank(attacker);
        vm.expectRevert();
        registry.setSubmissionBond(0);

        // The bond is still locked at the original amount
        assertEq(registry.bondOf(hashId), BOND);
    }

    // ========================================================================
    // 8. Reentrancy Attacks
    // ========================================================================

    function test_reentrancy_claimRefund_blocked() public {
        // Deploy a malicious receiver that re-enters claimRefund()
        MaliciousReceiver attk = new MaliciousReceiver(address(registry));
        vm.deal(address(attk), 10 ether);

        // Submit a proposal from the malicious contract
        vm.prank(address(attk));
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);

        // Attempt reentrancy — should be blocked by ReentrancyGuard
        vm.prank(address(attk));
        vm.expectRevert(); // ReentrancyGuard reverts on re-entry
        attk.attack();
    }

    // ========================================================================
    // 9. Constructor and Immutables
    // ========================================================================

    function test_constructor_zeroTreasury_reverts() public {
        vm.expectRevert(ECFPRegistry.ZeroTreasury.selector);
        new ECFPRegistry(admin, MIN_REVIEW, MAX_DRAFTS, BOND, address(0));
    }

    function test_constructor_zeroMaxDrafts_reverts() public {
        vm.expectRevert(ECFPRegistry.ZeroMaxDrafts.selector);
        new ECFPRegistry(admin, MIN_REVIEW, 0, BOND, treasury);
    }

    function test_constructor_parameters_stored() public view {
        assertEq(registry.maxDraftsPerAddress(), MAX_DRAFTS);
        assertEq(registry.submissionBond(), BOND);
        assertEq(registry.treasury(), treasury);
        assertEq(registry.minReviewPeriod(), MIN_REVIEW);
    }

    // ========================================================================
    // 10. Regression — Existing Lifecycle (bond=0 path for spec coverage)
    // ========================================================================

    function test_regression_fullLifecycle_noBond() public {
        // Simulate a testnet deployment with bond=0 — ensure all lifecycle transitions work
        ECFPRegistry noFeeRegistry =
            new ECFPRegistry(admin, MIN_REVIEW, MAX_DRAFTS, 0, treasury);

        vm.startPrank(admin);
        noFeeRegistry.grantRole(noFeeRegistry.GOVERNOR_ROLE(), governor);
        vm.stopPrank();

        vm.prank(alice);
        bytes32 hashId = noFeeRegistry.submit{value: 0}(ecfpId1, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        noFeeRegistry.activateProposal(hashId);

        vm.prank(governor);
        noFeeRegistry.approveProposal(hashId);

        vm.prank(governor);
        noFeeRegistry.markExecuted(hashId);

        ECFPRegistry.Proposal memory p = noFeeRegistry.getProposal(hashId);
        assertEq(uint8(p.status), uint8(ECFPRegistry.ProposalStatus.Executed));
    }

    function test_regression_rejectProposal_noBondTransfer() public {
        // Active rejection: bond already returned at activation, no additional transfer
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);

        uint256 pendingBefore = registry.pendingRefunds(alice);
        uint256 treasuryBefore = treasury.balance;

        vm.prank(governor);
        registry.rejectProposal(hashId);

        // No additional bond transfer on Active rejection
        assertEq(treasury.balance, treasuryBefore, "no extra slash on Active reject");
        assertEq(registry.pendingRefunds(alice), pendingBefore, "refund unchanged by reject");
    }

    function test_regression_batchExpire_requiresGovernorRole() public {
        bytes32 hashId = _submitWithBond(attacker, ecfpId1, BOND);
        bytes32[] memory hashIds = new bytes32[](1);
        hashIds[0] = hashId;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, registry.GOVERNOR_ROLE()
            )
        );
        vm.prank(alice); // not governor
        registry.batchExpire(hashIds);
    }

    function test_regression_batchExpire_invalidStatus_reverts() public {
        // batchExpire on an already-Active proposal that was activated (status != Draft && != Active... wait Active is valid)
        // Let's test: try to batchExpire an Executed proposal
        vm.prank(alice);
        bytes32 hashId = registry.submit{value: BOND}(ecfpId1, recipient, amount, metadataCID);

        vm.warp(block.timestamp + MIN_REVIEW + 1);
        vm.prank(governor);
        registry.activateProposal(hashId);
        vm.prank(governor);
        registry.approveProposal(hashId);
        vm.prank(governor);
        registry.markExecuted(hashId);

        bytes32[] memory hashIds = new bytes32[](1);
        hashIds[0] = hashId;

        vm.prank(governor);
        vm.expectRevert();
        registry.batchExpire(hashIds);
    }

    // ========================================================================
    // Internal helpers
    // ========================================================================

    function _submitWithBond(address proposer, bytes32 eid, uint256 bondAmount) internal returns (bytes32 hashId) {
        bytes32 meta = keccak256(abi.encodePacked("meta", eid));
        vm.prank(proposer);
        hashId = registry.submit{value: bondAmount}(eid, recipient, amount, meta);
    }
}

/// @dev Malicious receiver that re-enters claimRefund() on ETH receipt
contract MaliciousReceiver {
    ECFPRegistry public immutable target;
    bool public attacking;

    constructor(address _target) {
        target = ECFPRegistry(_target);
    }

    function attack() external {
        attacking = true;
        target.claimRefund();
    }

    receive() external payable {
        if (attacking) {
            attacking = false;
            target.claimRefund(); // attempt re-entry
        }
    }
}
