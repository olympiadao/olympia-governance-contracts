// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ECFPRegistry} from "../src/ECFPRegistry.sol";

/// @title RedeployECFPRegistry
/// @notice Legacy script — Demo v0.2 redeployment (archived). See DeployGovernance.s.sol for demo_v0.4.
/// @dev Same CREATE2 salt — different constructor args produce a different address
contract RedeployECFPRegistry is Script {
    bytes32 constant SALT = keccak256("OLYMPIA_DEMO_V0_2");
    uint256 constant MIN_REVIEW_PERIOD = 300; // 5 minutes (demo testing)

    // Legacy treasury placeholder (demo v0.2)
    address constant TREASURY = 0x60d0A7394f9Cd5C469f9F5Ec4F9C803F5294d79b;

    function run() public {
        address deployer = msg.sender;

        console.log("=== ECFPRegistry Redeployment (Demo v0.2 - legacy) ===");
        console.log("Deployer:", deployer);
        console.log("minReviewPeriod:", MIN_REVIEW_PERIOD);
        console.log("");

        vm.startBroadcast();

        // demo_v0.4 constructor: (admin, minReviewPeriod, maxDraftsPerAddress, initialBond, treasury)
        // Legacy deploy: no bond (0), no cap (max), treasury for interface compat
        ECFPRegistry registry = new ECFPRegistry{salt: SALT}(deployer, MIN_REVIEW_PERIOD, type(uint256).max, 0, TREASURY, address(0));
        console.log("ECFPRegistry (new):", address(registry));

        vm.stopBroadcast();

        console.log("");
        console.log("Next steps:");
        console.log("  1. Grant GOVERNOR_ROLE to Timelock on the new ECFPRegistry");
        console.log("  2. Update README with new ECFPRegistry address");
    }
}
