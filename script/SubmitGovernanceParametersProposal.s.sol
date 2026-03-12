// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceParametersProposal} from "src/proposals/GovernanceParametersProposal.sol";
import {SubmitProposal} from "script/SubmitProposal.s.sol";

contract SubmitGovernanceParametersProposalScript is SubmitProposal {
    function _proposal()
        internal
        pure
        override
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata)
    {
        return GovernanceParametersProposal.buildProposal();
    }
}
