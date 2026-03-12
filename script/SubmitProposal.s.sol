// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
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
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        (address strategy, IAzorius.Transaction[] memory txs, string memory metadata) = _proposal();

        vm.startBroadcast(pk);
        IAzorius(GovernanceProposal.AZORIUS()).submitProposal(strategy, hex"", txs, metadata);
        vm.stopBroadcast();
    }
}
