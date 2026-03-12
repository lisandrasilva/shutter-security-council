// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {SecurityCouncilProposal} from "src/proposals/SecurityCouncilProposal.sol";
import {SubmitProposal} from "script/SubmitProposal.s.sol";

contract SubmitSecurityCouncilProposalScript is SubmitProposal {
    function _proposal()
        internal
        view
        override
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata)
    {
        address guardAddress = vm.envAddress("GUARD_ADDRESS");
        return SecurityCouncilProposal.buildProposal(guardAddress);
    }
}
