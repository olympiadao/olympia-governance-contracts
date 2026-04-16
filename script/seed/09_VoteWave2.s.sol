// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {SeedConfig} from "./SeedConfig.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title 09_VoteWave2
/// @notice All three core maintainers cast FOR votes on the two Wave 2 proposals.
///
/// @dev Run after voting delay (~1 block from script 08 Phase B).
///
/// Run:
///   forge script script/seed/09_VoteWave2.s.sol \
///     --rpc-url $MORDOR_RPC_URL \
///     --broadcast --legacy -vvv
///
/// After: wait for voting period (~22 min), then run 10_QueueWave2.s.sol
contract VoteWave2 is Script, SeedConfig {
    uint8 internal constant FOR = 1;

    function run() public {
        address acme = vm.envAddress("ACME_ADDRESS");
        uint256 m1Pk = vm.envUint("MAINTAINER_1_PRIVATE_KEY");
        uint256 m2Pk = vm.envUint("MAINTAINER_2_PRIVATE_KEY");
        uint256 m3Pk = vm.envUint("MAINTAINER_3_PRIVATE_KEY");

        address m1 = vm.addr(m1Pk);
        address m2 = vm.addr(m2Pk);
        address m3 = vm.addr(m3Pk);

        uint256 propId5 = _proposalId(acme, AMOUNT_P5, descP5(acme));
        uint256 propId6 = _proposalId(acme, AMOUNT_P6, descP6(acme));

        console.log("=== 09_VoteWave2: Core maintainers vote FOR on Wave 2 proposals ===");
        console.log("Maintainer 1:", m1);
        console.log("Maintainer 2:", m2);
        console.log("Maintainer 3:", m3);
        console.log("");
        console.log("Proposal states (1=Active):");
        console.log("  P5 state:", uint8(GOVERNOR.state(propId5)));
        console.log("  P6 state:", uint8(GOVERNOR.state(propId6)));
        console.log("");

        vm.startBroadcast(m1Pk);
        GOVERNOR.castVote(propId5, FOR);
        GOVERNOR.castVote(propId6, FOR);
        vm.stopBroadcast();
        console.log("M1: voted FOR on P5 and P6");

        vm.startBroadcast(m2Pk);
        GOVERNOR.castVote(propId5, FOR);
        GOVERNOR.castVote(propId6, FOR);
        vm.stopBroadcast();
        console.log("M2: voted FOR on P5 and P6");

        vm.startBroadcast(m3Pk);
        GOVERNOR.castVote(propId5, FOR);
        GOVERNOR.castVote(propId6, FOR);
        vm.stopBroadcast();
        console.log("M3: voted FOR on P5 and P6");

        console.log("");
        console.log("=== 09_VoteWave2 complete ===");
        console.log("6 votes cast (3 maintainers x 2 proposals). All FOR.");
        console.log("");
        console.log("Wait for voting period (~100 blocks from proposal creation).");
        console.log("Then run 10_QueueWave2.s.sol");
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
}
