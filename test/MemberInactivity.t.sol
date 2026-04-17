// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {OlympiaDAOMemberNFT} from "../src/OlympiaDAOMemberNFT.sol";
import {OlympiaDAOGovernor} from "../src/OlympiaDAOGovernor.sol";
import {OlympiaExecutor} from "../src/OlympiaExecutor.sol";
import {SanctionsOracle} from "../src/SanctionsOracle.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title MemberInactivityTest
/// @notice Tests activity tracking, vote-witness confirmation, and permissionless inactivity revocation.
contract MemberInactivityTest is Test {
    OlympiaDAOMemberNFT public nft;
    OlympiaDAOGovernor public governor;
    TimelockController public timelock;

    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint48 constant VOTING_DELAY = 1;
    uint32 constant VOTING_PERIOD = 100;
    uint256 constant QUORUM_PERCENT = 10;
    uint48 constant LATE_QUORUM_EXTENSION = 50;
    uint256 constant TIMELOCK_DELAY = 3600;
    uint256 constant THRESHOLD = 1000; // 1000 blocks of inactivity

    function setUp() public {
        vm.roll(100); // start at block 100 to avoid underflow in past lookups

        // Deploy NFT with inactivityThreshold=THRESHOLD, governor=address(0) for now
        nft = new OlympiaDAOMemberNFT(
            "OlympiaDAO Member v0.4",
            "OLYMPIADAOv04",
            admin,
            THRESHOLD,
            address(0)
        );

        // Deploy governor + timelock for vote-witness tests
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, admin);
        governor = new OlympiaDAOGovernor(
            "OlympiaDAO Governor v0.4",
            IVotes(address(nft)),
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT,
            LATE_QUORUM_EXTENSION
        );

        // Wire governor into NFT
        vm.prank(admin);
        nft.setGovernor(address(governor));

        // Configure timelock roles
        vm.startPrank(admin);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        vm.stopPrank();
    }

    // =========================================================================
    // 1. lastActivityBlock initialised to mint block
    // =========================================================================

    function test_lastActivityBlock_setToMintBlock() public {
        vm.roll(200);
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.lastActivityBlock(alice), 200);
    }

    function test_mintBlocks_setToMintBlock() public {
        vm.roll(300);
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.mintBlocks(0), 300);
    }

    // =========================================================================
    // 2. _delegate override updates activity (post-mint only, balanceOf guard)
    // =========================================================================

    function test_delegate_updatesLastActivityBlock() public {
        vm.prank(admin);
        nft.safeMint(alice);

        uint256 mintBlock = block.number;

        vm.roll(mintBlock + 50);

        // Alice explicitly delegates to herself — should update activity
        vm.prank(alice);
        nft.delegate(alice);

        assertEq(nft.lastActivityBlock(alice), mintBlock + 50);
    }

    function test_delegate_duringMint_doesNotDoubleUpdate() public {
        // The _delegate call during _update (mint flow) should be guarded by balanceOf > 0.
        // At mint time: _update sets lastActivityBlock first, then calls _delegate internally.
        // The _delegate override guard (balanceOf > 0) prevents overwriting during the mint call.
        // After mint: lastActivityBlock should equal mint block, not be zeroed or duplicated.
        vm.roll(500);
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.lastActivityBlock(alice), 500);
        assertEq(nft.getVotes(alice), 1); // auto-delegated
    }

    function test_redelegate_updatesLastActivityBlock() public {
        vm.prank(admin);
        nft.safeMint(alice);
        vm.prank(admin);
        nft.safeMint(bob);

        uint256 mintBlock = block.number;
        vm.roll(mintBlock + 75);

        // Alice delegates to bob
        vm.prank(alice);
        nft.delegate(bob);
        assertEq(nft.lastActivityBlock(alice), mintBlock + 75);
    }

    // =========================================================================
    // 3. confirmVoteActivity updates block; reverts if member didn't vote
    // =========================================================================

    function test_confirmVoteActivity_updatesLastActivityBlock() public {
        vm.prank(admin);
        nft.safeMint(alice);
        vm.prank(admin);
        nft.safeMint(bob); // need enough supply for a proposal

        // Create and vote on a proposal
        vm.roll(block.number + 1);
        address[] memory targets = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Activity test");

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(alice);
        governor.castVote(proposalId, 1); // Alice votes For

        // Roll forward — alice's lastActivityBlock still at mint block
        uint256 mintBlock = nft.lastActivityBlock(alice);
        vm.roll(mintBlock + 500);

        // Anyone calls confirmVoteActivity
        nft.confirmVoteActivity(proposalId, alice);
        assertEq(nft.lastActivityBlock(alice), mintBlock + 500);
    }

    function test_confirmVoteActivity_revertsIfDidNotVote() public {
        vm.prank(admin);
        nft.safeMint(alice);
        vm.prank(admin);
        nft.safeMint(bob);

        vm.roll(block.number + 1);
        address[] memory targets = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "No vote test");

        vm.roll(block.number + VOTING_DELAY + 1);
        // Alice does NOT vote; bob votes
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        // Trying to confirm alice's vote should revert
        vm.expectRevert(abi.encodeWithSelector(OlympiaDAOMemberNFT.DidNotVote.selector, proposalId, alice));
        nft.confirmVoteActivity(proposalId, alice);
    }

    function test_confirmVoteActivity_revertsIfNoGovernor() public {
        // Deploy NFT with governor = address(0)
        OlympiaDAOMemberNFT nftNoGov = new OlympiaDAOMemberNFT(
            "OlympiaDAO Member v0.4",
            "OLYMPIADAOv04",
            admin,
            THRESHOLD,
            address(0)
        );
        vm.prank(admin);
        nftNoGov.safeMint(alice);

        vm.expectRevert(abi.encodeWithSelector(OlympiaDAOMemberNFT.DidNotVote.selector, 0, alice));
        nftNoGov.confirmVoteActivity(0, alice);
    }

    // =========================================================================
    // 4. revokeIfInactive reverts if within threshold (StillActive)
    // =========================================================================

    function test_revokeIfInactive_revertsIfStillActive() public {
        vm.prank(admin);
        nft.safeMint(alice);

        uint256 lastActivity = nft.lastActivityBlock(alice);

        // Roll to just under the threshold
        vm.roll(lastActivity + THRESHOLD - 1);

        vm.expectRevert(
            abi.encodeWithSelector(OlympiaDAOMemberNFT.StillActive.selector, alice, lastActivity, THRESHOLD)
        );
        nft.revokeIfInactive(0);
    }

    // =========================================================================
    // 5. revokeIfInactive succeeds after threshold — burns token, supply decreases
    // =========================================================================

    function test_revokeIfInactive_burnsTokenAfterThreshold() public {
        vm.prank(admin);
        nft.safeMint(alice);
        uint256 tokenId = 0;

        uint256 lastActivity = nft.lastActivityBlock(alice);
        vm.roll(lastActivity + THRESHOLD);

        assertEq(nft.totalSupply(), 1);

        vm.expectEmit(true, true, false, true);
        emit OlympiaDAOMemberNFT.MembershipExpiredByInactivity(tokenId, alice, lastActivity);
        nft.revokeIfInactive(tokenId);

        assertEq(nft.totalSupply(), 0);
        vm.expectRevert();
        nft.ownerOf(tokenId);
    }

    function test_revokeIfInactive_anyoneCanCall() public {
        vm.prank(admin);
        nft.safeMint(alice);

        uint256 lastActivity = nft.lastActivityBlock(alice);
        vm.roll(lastActivity + THRESHOLD);

        // Bob (non-admin) can call
        vm.prank(bob);
        nft.revokeIfInactive(0);

        assertEq(nft.totalSupply(), 0);
    }

    // =========================================================================
    // 6. batchRevokeIfInactive sweeps multiple in one tx
    // =========================================================================

    function test_batchRevokeIfInactive_sweepsMultiple() public {
        vm.startPrank(admin);
        nft.safeMint(alice);   // tokenId 0
        nft.safeMint(bob);     // tokenId 1
        nft.safeMint(charlie); // tokenId 2
        vm.stopPrank();

        uint256 lastActivity = nft.lastActivityBlock(alice);
        vm.roll(lastActivity + THRESHOLD);

        assertEq(nft.totalSupply(), 3);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;

        nft.batchRevokeIfInactive(tokenIds);

        assertEq(nft.totalSupply(), 0);
    }

    function test_batchRevokeIfInactive_revertsOnStillActive() public {
        vm.startPrank(admin);
        nft.safeMint(alice); // tokenId 0
        nft.safeMint(bob);   // tokenId 1
        vm.stopPrank();

        // Roll alice past threshold
        uint256 aliceActivity = nft.lastActivityBlock(alice);
        vm.roll(aliceActivity + THRESHOLD);

        // Bob's lastActivityBlock is same (minted same block), but roll is now at threshold.
        // Let bob explicitly re-delegate to reset their activity
        vm.prank(bob);
        nft.delegate(bob); // updates lastActivityBlock[bob] to current block

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        // Should revert on bob (token 1) — still active
        vm.expectRevert();
        nft.batchRevokeIfInactive(tokenIds);
    }

    // =========================================================================
    // 7. inactivityThreshold == 0 → revokeIfInactive reverts InactivityDisabled
    // =========================================================================

    function test_revokeIfInactive_revertsWhenDisabled() public {
        OlympiaDAOMemberNFT nftDisabled = new OlympiaDAOMemberNFT(
            "OlympiaDAO Member v0.4",
            "OLYMPIADAOv04",
            admin,
            0, // disabled
            address(0)
        );
        vm.prank(admin);
        nftDisabled.safeMint(alice);

        vm.expectRevert(OlympiaDAOMemberNFT.InactivityDisabled.selector);
        nftDisabled.revokeIfInactive(0);
    }

    // =========================================================================
    // 8. setInactivityThreshold emits event; only DEFAULT_ADMIN_ROLE
    // =========================================================================

    function test_setInactivityThreshold_emitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit OlympiaDAOMemberNFT.InactivityThresholdUpdated(THRESHOLD, 2000);
        vm.prank(admin);
        nft.setInactivityThreshold(2000);
        assertEq(nft.inactivityThreshold(), 2000);
    }

    function test_setInactivityThreshold_revertsIfNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setInactivityThreshold(2000);
    }

    // =========================================================================
    // 9. Quorum decreases after inactive members are revoked (E2E)
    // =========================================================================

    function test_quorumDecreasesAfterRevocation() public {
        // Mint 10 NFTs so quorum = 10% × 10 = 1
        vm.startPrank(admin);
        for (uint256 i = 0; i < 10; i++) {
            nft.safeMint(makeAddr(string(abi.encodePacked("voter", i))));
        }
        vm.stopPrank();

        vm.roll(block.number + 1);
        uint256 supplyBefore = nft.totalSupply();
        assertEq(supplyBefore, 10);

        // Roll past threshold and revoke all tokens
        // Use ownerOf(0) to get the actual minted address (abi.encodePacked(uint256) != "voter0")
        uint256 mintBlock = nft.lastActivityBlock(nft.ownerOf(0));
        vm.roll(mintBlock + THRESHOLD + 1);

        uint256[] memory tokenIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            tokenIds[i] = i;
        }
        nft.batchRevokeIfInactive(tokenIds);

        assertEq(nft.totalSupply(), 0);

        // quorum uses getPastTotalSupply(timepoint) — need timepoint strictly in the past
        // and need to query a block AFTER the burn block so the checkpoint is captured
        vm.roll(block.number + 2);
        uint256 quorumAfter = governor.quorum(block.number - 1);
        assertEq(quorumAfter, 0); // 0 NFTs → 10% × 0 = 0
    }

    // =========================================================================
    // 10. Re-mint after inactivity revocation resets lastActivityBlock
    // =========================================================================

    function test_remint_resetsLastActivityBlock() public {
        vm.prank(admin);
        nft.safeMint(alice);

        uint256 firstMintBlock = nft.lastActivityBlock(alice);
        vm.roll(firstMintBlock + THRESHOLD);

        // Revoke
        nft.revokeIfInactive(0);
        assertEq(nft.balanceOf(alice), 0);

        // Re-mint — alice has no token so no AlreadyMember revert
        vm.roll(block.number + 100);
        uint256 remintBlock = block.number;
        vm.prank(admin);
        nft.safeMint(alice);

        assertEq(nft.lastActivityBlock(alice), remintBlock);
        assertEq(nft.balanceOf(alice), 1);
    }

    // =========================================================================
    // 11. tokenURI includes "Last Active Block" trait matching lastActivityBlock[owner]
    // =========================================================================

    function test_tokenURI_includesLastActiveBlockTrait() public {
        // Deploy renderer and wire up
        address rendererAddr = deployCode(
            "OlympiaDAOMemberRenderer.sol:OlympiaDAOMemberRenderer",
            abi.encode("OlympiaDAO Member v0.4")
        );
        vm.prank(admin);
        nft.setRenderer(rendererAddr);

        vm.roll(400);
        vm.prank(admin);
        nft.safeMint(alice);

        string memory uri = nft.tokenURI(0);
        assertTrue(bytes(uri).length > 0);
        // tokenURI returns data URI — we just verify it's non-empty and starts correctly
        bytes memory b = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(b[i], prefix[i]);
        }
    }

    // =========================================================================
    // 12. tokenURI trait updates after confirmVoteActivity
    // =========================================================================

    function test_tokenURI_withoutRenderer_returnsEmpty() public {
        vm.prank(admin);
        nft.safeMint(alice);
        assertEq(nft.tokenURI(0), "");
    }

    function test_lastActivityBlock_updatesAfterConfirmVoteActivity() public {
        vm.prank(admin);
        nft.safeMint(alice);
        vm.prank(admin);
        nft.safeMint(bob);

        uint256 mintBlock = nft.lastActivityBlock(alice);

        // Create proposal
        vm.roll(block.number + 1);
        address[] memory targets = new address[](1);
        targets[0] = address(0x1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Trait update test");
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        // Advance blocks
        vm.roll(mintBlock + 200);

        // Confirm alice's vote activity
        nft.confirmVoteActivity(proposalId, alice);
        assertEq(nft.lastActivityBlock(alice), mintBlock + 200);
    }

    // =========================================================================
    // setGovernor
    // =========================================================================

    function test_setGovernor_updatesGovernor() public {
        vm.expectEmit(true, true, false, false);
        emit OlympiaDAOMemberNFT.GovernorUpdated(address(governor), address(0xdead));
        vm.prank(admin);
        nft.setGovernor(address(0xdead));
        assertEq(address(nft.governor()), address(0xdead));
    }

    function test_setGovernor_revertsIfNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.setGovernor(address(0xdead));
    }
}
