// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

/// @notice Builds the governance proposal that installs the security council guard
///         with a 2-day timelock.
///
/// Transaction order matters: set the timelock first, then install the guard.
/// This ensures the guard is never active without a proper timelock window.
///
/// Transactions:
///   0. Azorius.updateTimelockPeriod(14_400)  — 2-day timelock
///   1. Azorius.setGuard(guardAddress)        — install the veto guard
library SecurityCouncilProposal {
    uint32 internal constant TIMELOCK_PERIOD = 14_400;

    function buildProposalTransactions(address guardAddress) internal pure returns (IAzorius.Transaction[] memory txs) {
        txs = new IAzorius.Transaction[](2);

        txs[0] = IAzorius.Transaction({
            to: GovernanceProposal.AZORIUS(),
            value: 0,
            data: abi.encodeCall(IAzorius.updateTimelockPeriod, (TIMELOCK_PERIOD)),
            operation: IAzorius.Operation.Call
        });

        txs[1] = IAzorius.Transaction({
            to: GovernanceProposal.AZORIUS(),
            value: 0,
            data: abi.encodeCall(IAzorius.setGuard, (guardAddress)),
            operation: IAzorius.Operation.Call
        });
    }

    function metadata() internal pure returns (string memory) {
        return '{"title":"Security Council Guard Installation","description":"Install security council veto guard with a 2-day timelock for the council veto window"}';
    }

    function buildProposal(address guardAddress)
        internal
        pure
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory _metadata)
    {
        strategy = GovernanceProposal.LINEAR_ERC20_VOTING();
        txs = buildProposalTransactions(guardAddress);
        _metadata = metadata();
    }
}
