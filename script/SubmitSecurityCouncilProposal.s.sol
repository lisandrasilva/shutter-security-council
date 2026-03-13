// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";
import {SecurityCouncilProposal} from "src/proposals/SecurityCouncilProposal.sol";
import {SubmitProposal} from "script/SubmitProposal.s.sol";

contract SubmitSecurityCouncilProposalScript is SubmitProposal {
    string internal constant TITLE = "[SECURITY] Implement Security Council to Prevent Governance Attacks";
    string internal constant DESCRIPTION_PATH = "docs/comms/proposal-1-security-council-guard.md";

    function _proposal()
        internal
        override
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata)
    {
        address guardAddress = vm.envAddress("GUARD_ADDRESS");
        txs = SecurityCouncilProposal.buildProposalTransactions(guardAddress);
        strategy = GovernanceProposal.LINEAR_ERC20_VOTING();

        string memory description = vm.readFile(DESCRIPTION_PATH);
        metadata = _buildMetadataJson(TITLE, description);
    }
}
