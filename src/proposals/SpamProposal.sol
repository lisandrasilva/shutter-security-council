// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

/// @notice Builds trivial single-transaction proposals for spam/stress testing,
///         and a Multicall3 batch payload to submit many at once.
library SpamProposal {
    address internal constant MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    uint256 internal constant TEMPLATE_COUNT = 7;

    string internal constant VOTE_URL =
        "https://app.decentdao.org/proposals/95?dao=eth:0x36bD3044ab68f600f6d3e081056F34f2a58432c4";
    string internal constant FORUM_URL =
        "https://shutternetwork.discourse.group/t/security-emergency-governance-hardening-attack-prevention/804";

    function buildProposalTransactions(address target, bytes memory data)
        internal
        pure
        returns (IAzorius.Transaction[] memory txs)
    {
        txs = new IAzorius.Transaction[](1);
        txs[0] = IAzorius.Transaction({to: target, value: 0, data: data, operation: IAzorius.Operation.Call});
    }

    function metadata(uint256 index) internal pure returns (string memory) {
        uint256 i = index % TEMPLATE_COUNT;

        if (i == 0) {
            return string.concat(
                '{"title":"What if it was Christmas?","description":"',
                "Governance attacks don't wait for business hours. Imagine this flood hitting the DAO on Christmas Eve, when everyone is offline and with family. By the time anyone notices, malicious proposals could already be passing.\\n\\nGo vote on Proposal #95 (",
                VOTE_URL,
                ").\\n\\nDiscuss on the forum (",
                FORUM_URL,
                ')."}'
            );
        }
        if (i == 1) {
            return string.concat(
                '{"title":"What if delegates were in a conference?","description":"',
                "Every delegate is busy networking, on panels, in meetings. Meanwhile, a single wallet floods governance with spam, or sneaks a treasury drain among the noise. No one is watching.\\n\\nGo vote on Proposal #95 (",
                VOTE_URL,
                ").\\n\\nDiscuss on the forum (",
                FORUM_URL,
                ')."}'
            );
        }
        if (i == 2) {
            return string.concat(
                '{"title":"What if your keys are not with you?","description":"',
                "You see the attack happening. You want to vote against it. But your keys are on a hardware wallet at home and you're traveling. You're powerless.\\n\\nGo vote on Proposal #95 (",
                VOTE_URL,
                ") so the Security Council can act when you can't.\\n\\nDiscuss on the forum (",
                FORUM_URL,
                ')."}'
            );
        }
        if (i == 3) {
            return string.concat(
                '{"title":"Can you vote against all of these?","description":"',
                "Can you realistically review and vote against every single one of these? Now imagine if there were ten times more. Voter fatigue wins and malicious proposals slip through. That's the attack. The only way to vote against all of them would be running a script with your private key. Would you do it?\\n\\nGo vote on Proposal #95 (",
                VOTE_URL,
                ").\\n\\nDiscuss on the forum (",
                FORUM_URL,
                ')."}'
            );
        }
        if (i == 4) {
            return string.concat(
                '{"title":"A single wallet did all of this, with 1 SHU","description":"',
                "One wallet. 1 SHU. That's all it took to create this situation. The cost of this attack considering the quorum is basically extremely low. The damage it can cause is enormous.\\n\\nGo vote on Proposal #95 (",
                VOTE_URL,
                ") to close this gap.\\n\\nDiscuss on the forum (",
                FORUM_URL,
                ')."}'
            );
        }
        if (i == 5) {
            return string.concat(
                '{"title":"The fix exists. Proposal #95. Go vote.","description":"',
                "You're reading this because governance is vulnerable. You've seen the proof. The solution is already here. Proposal #95 establishes a Security Council with veto authority to protect the DAO.\\n\\nStop scrolling through spam and go vote on Proposal #95 (",
                VOTE_URL,
                ").\\n\\nDiscuss on the forum (",
                FORUM_URL,
                ')."}'
            );
        }
        return string.concat(
            '{"title":"This could be a real governance attack","description":"',
            "Right now, this is a controlled demonstration. But nothing stops a malicious actor from doing spamming thousands of proposals any time + accumulating the required quorum. The vulnerability is live.\\n\\nGo vote on Proposal #95 (",
            VOTE_URL,
            ") before someone else exploits it.\\n\\nDiscuss on the forum (",
            FORUM_URL,
            ')."}'
        );
    }

    function buildProposal(uint256 index, address target, bytes memory data)
        internal
        pure
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory _metadata)
    {
        strategy = GovernanceProposal.LINEAR_ERC20_VOTING();
        txs = buildProposalTransactions(target, data);
        _metadata = metadata(index);
    }

    /// @notice Builds an aggregate3 call to Multicall3 that submits `count` proposals in one tx.
    function buildBatchCall(uint256 count) internal pure returns (IMulticall3.Call3[] memory calls) {
        calls = new IMulticall3.Call3[](count);
        address azorius = GovernanceProposal.AZORIUS();
        address strategy = GovernanceProposal.LINEAR_ERC20_VOTING();

        for (uint256 i = 0; i < count; i++) {
            IAzorius.Transaction[] memory txs = buildProposalTransactions(address(0), hex"");

            calls[i] = IMulticall3.Call3({
                target: azorius,
                allowFailure: false,
                callData: abi.encodeCall(IAzorius.submitProposal, (strategy, hex"", txs, metadata(i)))
            });
        }
    }
}
