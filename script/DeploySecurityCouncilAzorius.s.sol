// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";

contract DeploySecurityCouncilAzorius is Script {
    function run() external returns (SecurityCouncilAzorius deployed) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address councilAddress = vm.envAddress("COUNCIL_ADDRESS");
        address azoriusAddress = vm.envAddress("AZORIUS_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        deployed = new SecurityCouncilAzorius(councilAddress, azoriusAddress);
        vm.stopBroadcast();
    }
}
