// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

/// @notice Base script for submitting a governance proposal to Azorius.
///         Concrete scripts override `_proposal()` to supply their payload.
abstract contract SubmitProposal is Script {
    function _proposal()
        internal
        view
        virtual
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata);

    function run() external {
        (address strategy, IAzorius.Transaction[] memory txs, string memory metadata) = _proposal();

        address to = GovernanceProposal.AZORIUS();
        bytes memory callData =
            abi.encodeCall(IAzorius.submitProposal, (strategy, hex"", txs, metadata));

        console.log("to:", to);
        console.log("calldata:");
        console.logBytes(callData);

        uint256 pk = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0));
        if (pk != 0) {
            vm.startBroadcast(pk);
        } else {
            vm.startBroadcast();
        }

        IAzorius(to).submitProposal(strategy, hex"", txs, metadata);
        vm.stopBroadcast();
    }
}
