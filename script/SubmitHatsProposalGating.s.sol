// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {HatsProposalGatingProposal} from "src/proposals/HatsProposalGatingProposal.sol";
import {SubmitProposal} from "script/SubmitProposal.s.sol";

contract SubmitHatsProposalGatingScript is SubmitProposal {
    function _proposalHatWearers() internal view virtual returns (address[] memory wearers) {
        string memory wearersJson = vm.envString("PROPOSER_HAT_WEARERS");
        string memory wrappedJson = string.concat('{"wearers":', wearersJson, "}");
        wearers = vm.parseJsonAddressArray(wrappedJson, ".wearers");
    }

    function _proposal()
        internal
        view
        override
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata)
    {
        address[] memory wearers = _proposalHatWearers();
        return HatsProposalGatingProposal.buildProposal(wearers);
    }
}
