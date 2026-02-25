// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProposalSpamTest
 * @notice Fork test proving that 1 000 proposals can be submitted to
 *         Azorius on mainnet without hitting any gas or storage limit.
 */

import {ShutterGovernanceBaseForkTest, IAzoriusFork} from "./ShutterGovernance.base.t.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

contract ProposalSpamTest is ShutterGovernanceBaseForkTest {
    MockTarget internal target;

    function setUp() public override {
        super.setUp();
        target = new MockTarget();
        vm.label(address(target), "SpamTarget");
    }

    function _prepareTransactions()
        internal
        view
        override
        returns (IAzoriusFork.Transaction[] memory txs)
    {} // Not used — we build per-iteration transactions below.

    function _txsForNumber(uint256 number) internal view returns (IAzoriusFork.Transaction[] memory txs) {
        txs = new IAzoriusFork.Transaction[](1);
        txs[0] = IAzoriusFork.Transaction({
            to: address(target),
            value: 0,
            data: abi.encodeCall(MockTarget.setNumber, (number)),
            operation: IAzoriusFork.Operation.Call
        });
    }

    function test_thousandProposalsCanBeSubmitted() public {
        uint256 count = 1_000;
        uint32 firstProposalId = AZORIUS.totalProposalCount();

        for (uint256 i = 0; i < count; i++) {
            vm.prank(proposer);
            AZORIUS.submitProposal(address(LINEAR_ERC20_VOTING), hex"", _txsForNumber(i), _metadata());
        }

        assertEq(AZORIUS.totalProposalCount() - firstProposalId, count, "Expected 1000 proposals submitted");
    }
}
