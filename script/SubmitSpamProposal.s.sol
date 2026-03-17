// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {SpamProposal} from "src/proposals/SpamProposal.sol";

/// @notice Submits N spam proposals batched via Multicall3 in a single transaction.
contract SubmitSpamProposalScript is Script {
    function run() external {
        uint256 count = vm.envOr("SPAM_COUNT", uint256(8));

        IMulticall3.Call3[] memory calls = SpamProposal.buildBatchCall(count);

        address to = SpamProposal.MULTICALL3;
        bytes memory callData = abi.encodeCall(IMulticall3.aggregate3, (calls));

        console.log("to:", to);
        console.log("calldata:");
        console.logBytes(callData);

        uint256 pk = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0));
        if (pk != 0) {
            vm.startBroadcast(pk);
        } else {
            vm.startBroadcast();
        }

        IMulticall3(to).aggregate3(calls);
        vm.stopBroadcast();
    }
}
