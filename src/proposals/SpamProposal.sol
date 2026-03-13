// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

/// @notice Builds trivial single-transaction proposals for spam/stress testing,
///         and a Multicall3 batch payload to submit many at once.
library SpamProposal {
    address internal constant MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    function buildProposalTransactions(address target, bytes memory data)
        internal
        pure
        returns (IAzorius.Transaction[] memory txs)
    {
        txs = new IAzorius.Transaction[](1);
        txs[0] = IAzorius.Transaction({to: target, value: 0, data: data, operation: IAzorius.Operation.Call});
    }

    function metadata() internal pure returns (string memory) {
        return '{"title":"This could have been an attack","description":"DISCOURSE LINK"}';
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

    /// @notice Builds an aggregate3 call to Multicall3 that submits `count` proposals in one tx.
    function buildBatchCall(uint256 count) internal pure returns (IMulticall3.Call3[] memory calls) {
        calls = new IMulticall3.Call3[](count);
        address azorius = GovernanceProposal.AZORIUS();
        address strategy = GovernanceProposal.LINEAR_ERC20_VOTING();
        string memory _metadata = metadata();

        for (uint256 i = 0; i < count; i++) {
            IAzorius.Transaction[] memory txs =
                buildProposalTransactions(address(0), hex"");

            calls[i] = IMulticall3.Call3({
                target: azorius,
                allowFailure: false,
                callData: abi.encodeCall(IAzorius.submitProposal, (strategy, hex"", txs, _metadata))
            });
        }
    }
}
