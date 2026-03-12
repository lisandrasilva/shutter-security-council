// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

/// @notice Builds a trivial single-transaction proposal for spam/stress testing.
library SpamProposal {
    function buildProposalTransactions(address target, bytes memory data)
        internal
        pure
        returns (IAzorius.Transaction[] memory txs)
    {
        txs = new IAzorius.Transaction[](1);
        txs[0] = IAzorius.Transaction({to: target, value: 0, data: data, operation: IAzorius.Operation.Call});
    }

    function metadata() internal pure returns (string memory) {
        return '{"title":"Spam Proposal","description":"Trivial proposal for stress testing"}';
    }

    function buildProposal(address target, bytes memory data)
        internal
        pure
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory _metadata)
    {
        strategy = GovernanceProposal.LINEAR_ERC20_VOTING();
        txs = buildProposalTransactions(target, data);
        _metadata = metadata();
    }
}
