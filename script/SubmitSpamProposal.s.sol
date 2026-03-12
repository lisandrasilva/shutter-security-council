// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";
import {SpamProposal} from "src/proposals/SpamProposal.sol";

/// @notice Submits N spam proposals in a loop for stress testing.
///         Does NOT extend SubmitProposal because it submits multiple proposals.
contract SubmitSpamProposalScript is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 count = vm.envOr("SPAM_COUNT", uint256(100));
        address target = vm.envAddress("SPAM_TARGET");

        vm.startBroadcast(pk);
        for (uint256 i = 0; i < count; i++) {
            (address strategy, IAzorius.Transaction[] memory txs, string memory metadata) =
                SpamProposal.buildProposal(target, abi.encodeWithSignature("setNumber(uint256)", i));
            IAzorius(GovernanceProposal.AZORIUS()).submitProposal(strategy, hex"", txs, metadata);
        }
        vm.stopBroadcast();
    }
}
