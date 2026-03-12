// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {SpamProposal} from "src/proposals/SpamProposal.sol";

/// @notice Submits N spam proposals batched via Multicall3 in a single transaction.
contract SubmitSpamProposalScript is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 count = vm.envOr("SPAM_COUNT", uint256(100));
        address target = vm.envAddress("SPAM_TARGET");

        IMulticall3.Call3[] memory calls = SpamProposal.buildBatchCall(target, count);

        vm.startBroadcast(pk);
        IMulticall3(SpamProposal.MULTICALL3).aggregate3(calls);
        vm.stopBroadcast();
    }
}
