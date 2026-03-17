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
        virtual
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata);

    /// @notice Builds a properly JSON-escaped metadata string from title and description.
    ///         Uses vm.serializeString to escape newlines, quotes, and other special characters.
    function _buildMetadataJson(string memory title, string memory description) internal returns (string memory) {
        vm.serializeString("metadata", "title", title);
        return vm.serializeString("metadata", "description", description);
    }

    function run() external {
        (address strategy, IAzorius.Transaction[] memory txs, string memory metadata) = _proposal();

        address to = GovernanceProposal.AZORIUS();
        bytes memory callData = abi.encodeCall(IAzorius.submitProposal, (strategy, hex"", txs, metadata));

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
