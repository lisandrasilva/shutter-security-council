// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";

contract DeploySecurityCouncilAzorius is Script {
    function run() external returns (SecurityCouncilAzorius deployed) {
        address councilAddress = vm.envAddress("COUNCIL_ADDRESS");
        address azoriusAddress = vm.envAddress("AZORIUS_ADDRESS");

        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0));
        if (deployerPrivateKey != 0) {
            vm.startBroadcast(deployerPrivateKey);
        } else {
            vm.startBroadcast();
        }

        deployed = new SecurityCouncilAzorius(councilAddress, azoriusAddress);
        vm.stopBroadcast();
    }
}
