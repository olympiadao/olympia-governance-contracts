// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title 04_VoteWave1
/// @notice All three core maintainers cast FOR votes on the four Wave 1 proposals.
///         Each maintainer votes in a separate broadcast to produce distinct timestamps.
///         Votes are cast sequentially: M1 votes all proposals, then M2, then M3.
///
/// @dev Run after voting delay has elapsed (~1 block, ~13s after script 03 Phase B).
///      Voting window is 100 blocks (~22 minutes). All votes must be cast within this window.
///      Support values: 0 = Against, 1 = For, 2 = Abstain.
///
/// Run:
///   forge script script/seed/04_VoteWave1.s.sol \
///     --rpc-url $MORDOR_RPC_URL \
///     --broadcast --legacy -vvv
///
/// After running: wait for voting period to end (~22 min from proposal creation),
///               then run 05_QueueWave1.s.sol
contract VoteWave1 is Script, SeedConfig {
    uint8 internal constant FOR = 1;

    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");
        uint256 m1Pk = vm.envUint("MAINTAINER_1_PRIVATE_KEY");
        uint256 m2Pk = vm.envUint("MAINTAINER_2_PRIVATE_KEY");
        uint256 m3Pk = vm.envUint("MAINTAINER_3_PRIVATE_KEY");

        address m1 = vm.addr(m1Pk);
        address m2 = vm.addr(m2Pk);
        address m3 = vm.addr(m3Pk);

        // Compute proposal IDs deterministically from the same inputs used in script 03
        uint256 propId1 = _proposalId(acme, AMOUNT_P1, descP1(acme));
        uint256 propId2 = _proposalId(acme, AMOUNT_P2, descP2(acme));
        uint256 propId3 = _proposalId(acme, AMOUNT_P3, descP3(acme));
        uint256 propId4 = _proposalId(acme, AMOUNT_P4, descP4(acme));

        console.log("=== 04_VoteWave1: Core maintainers vote FOR on Wave 1 proposals ===");
        console.log("Maintainer 1:", m1);
        console.log("Maintainer 2:", m2);
        console.log("Maintainer 3:", m3);
        console.log("");
        _logProposalStates(propId1, propId2, propId3, propId4);

        // ── Maintainer 1 votes ────────────────────────────────────────────────
        console.log("--- Maintainer 1 casting votes ---");
        vm.startBroadcast(m1Pk);
        GOVERNOR.castVote(propId1, FOR);
        GOVERNOR.castVote(propId2, FOR);
        GOVERNOR.castVote(propId3, FOR);
        GOVERNOR.castVote(propId4, FOR);
        vm.stopBroadcast();
        console.log("  M1: voted FOR on all 4 proposals");
        console.log("");

        // ── Maintainer 2 votes ────────────────────────────────────────────────
        console.log("--- Maintainer 2 casting votes ---");
        vm.startBroadcast(m2Pk);
        GOVERNOR.castVote(propId1, FOR);
        GOVERNOR.castVote(propId2, FOR);
        GOVERNOR.castVote(propId3, FOR);
        GOVERNOR.castVote(propId4, FOR);
        vm.stopBroadcast();
        console.log("  M2: voted FOR on all 4 proposals");
        console.log("");

        // ── Maintainer 3 votes ────────────────────────────────────────────────
        console.log("--- Maintainer 3 casting votes ---");
        vm.startBroadcast(m3Pk);
        GOVERNOR.castVote(propId1, FOR);
        GOVERNOR.castVote(propId2, FOR);
        GOVERNOR.castVote(propId3, FOR);
        GOVERNOR.castVote(propId4, FOR);
        vm.stopBroadcast();
        console.log("  M3: voted FOR on all 4 proposals");
        console.log("");

        console.log("=== 04_VoteWave1 complete ===");
        console.log("12 votes cast (3 maintainers x 4 proposals). All FOR.");
        console.log("");
        console.log("Wait for voting period to end (~100 blocks from proposal creation).");
        console.log("Then run 05_QueueWave1.s.sol");
        console.log("");
        console.log("While waiting, you can submit Wave 2 ECFPs:");
        console.log("  Run 07_SubmitWave2ECFPs.s.sol (ACME key) after 5 minutes");
    }

    function _proposalId(address acme, uint256 amount, string memory desc)
        internal
        view
        returns (uint256)
    {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _proposalActions(acme, amount);
        return GOVERNOR.hashProposal(targets, values, calldatas, keccak256(bytes(desc)));
    }

    function _logProposalStates(uint256 id1, uint256 id2, uint256 id3, uint256 id4) internal view {
        console.log("Proposal states (1=Active, 0=Pending):");
        console.log("  P1:", uint8(GOVERNOR.state(id1)));
        console.log("  P2:", uint8(GOVERNOR.state(id2)));
        console.log("  P3:", uint8(GOVERNOR.state(id3)));
        console.log("  P4:", uint8(GOVERNOR.state(id4)));
        console.log("");
    }
}
