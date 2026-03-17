// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {ILinearERC20Voting} from "src/interfaces/ILinearERC20Voting.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

/// @notice Builds the governance proposal that hardens governance parameters.
///         Submitted separately from the guard installation so each change
///         can be voted on independently.
///
/// Transactions:
///   0. Azorius.updateExecutionPeriod(50_400)                           — 7-day execution window
///   1. LinearERC20Voting.updateRequiredProposerWeight(100_000e18)      — 100K SHU threshold
library GovernanceParametersProposal {
    uint32 internal constant EXECUTION_PERIOD = 50_400;
    uint256 internal constant REQUIRED_PROPOSER_WEIGHT = 100_000e18;

    function buildProposalTransactions() internal pure returns (IAzorius.Transaction[] memory txs) {
        txs = new IAzorius.Transaction[](2);

        txs[0] = IAzorius.Transaction({
            to: GovernanceProposal.AZORIUS(),
            value: 0,
            data: abi.encodeCall(IAzorius.updateExecutionPeriod, (EXECUTION_PERIOD)),
            operation: IAzorius.Operation.Call
        });

        txs[1] = IAzorius.Transaction({
            to: GovernanceProposal.LINEAR_ERC20_VOTING(),
            value: 0,
            data: abi.encodeCall(ILinearERC20Voting.updateRequiredProposerWeight, (REQUIRED_PROPOSER_WEIGHT)),
            operation: IAzorius.Operation.Call
        });
    }

    function metadata() internal pure returns (string memory) {
        return '{"title":"Governance Parameters Hardening","description":"Extend execution window to 7 days and raise proposer threshold to 100K SHU"}';
    }

    function buildProposal()
        internal
        pure
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory _metadata)
    {
        strategy = GovernanceProposal.LINEAR_ERC20_VOTING();
        txs = buildProposalTransactions();
        _metadata = metadata();
    }
}
