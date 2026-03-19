// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";

/// @title RedeployECFPRegistry
/// @notice Redeploys ECFPRegistry with a shorter minReviewPeriod for demo testing
/// @dev Same CREATE2 salt — different constructor args produce a different address
contract RedeployECFPRegistry is Script {
    bytes32 constant SALT = keccak256("OLYMPIA_DEMO_V0_2");
    uint256 constant MIN_REVIEW_PERIOD = 300; // 5 minutes (demo testing)

    function run() public {
        address deployer = msg.sender;

        console.log("=== ECFPRegistry Redeployment (Demo v0.2) ===");
        console.log("Deployer:", deployer);
        console.log("minReviewPeriod:", MIN_REVIEW_PERIOD);
        console.log("");

        vm.startBroadcast();

        ECFPRegistry registry = new ECFPRegistry{salt: SALT}(deployer, MIN_REVIEW_PERIOD);
        console.log("ECFPRegistry (new):", address(registry));

        vm.stopBroadcast();

        console.log("");
        console.log("Next steps:");
        console.log("  1. Grant GOVERNOR_ROLE to Timelock on the new ECFPRegistry");
        console.log("  2. Update README with new ECFPRegistry address");
    }
}
