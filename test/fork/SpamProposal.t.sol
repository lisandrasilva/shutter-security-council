// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SpamProposalTest
 * @notice Fork test for the SpamProposal library.
 *
 * Tests:
 *   1. 1000 spam proposals can be batched via Multicall3 in a single tx.
 *   2. After GovernanceParametersProposal raises the threshold to 100K SHU,
 *      a low-weight address is blocked from submitting.
 */
import {ShutterGovernanceBaseForkTest, IVotesFork} from "./ShutterGovernance.base.t.sol";
import {IAzorius as IAzoriusFork} from "src/interfaces/IAzorius.sol";
import {IMulticall3} from "forge-std/interfaces/IMulticall3.sol";
import {GovernanceParametersProposal} from "src/proposals/GovernanceParametersProposal.sol";
import {SpamProposal} from "src/proposals/SpamProposal.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

contract SpamProposalTest is ShutterGovernanceBaseForkTest {
    MockTarget internal target;

    function setUp() public override {
        super.setUp();
        vm.skip(vm.envOr("CI", false), "SpamProposal skipped in CI (117M gas)");
        target = new MockTarget();
        vm.label(address(target), "SpamTarget");
    }

    function _prepareTransactions() internal view override returns (IAzoriusFork.Transaction[] memory) {
        return SpamProposal.buildProposalTransactions(address(target), abi.encodeCall(MockTarget.setNumber, (0)));
    }

    function _metadata() internal pure override returns (string memory) {
        return SpamProposal.metadata();
    }

    function test_thousandProposalsBatchedViaMulticall3() public {
        uint256 count = 1_000;
        uint32 firstProposalId = AZORIUS.totalProposalCount();

        // Multicall3 becomes msg.sender for Azorius, so it needs proposer weight.
        // Give a fresh address exactly 1 SHU (the current minimum) and delegate to Multicall3.
        address spammer = address(0xBAD);
        deal(SHUTTER_TOKEN, spammer, 1e18);
        vm.prank(spammer);
        IVotesFork(SHUTTER_TOKEN).delegate(SpamProposal.MULTICALL3);
        vm.roll(block.number + 1);

        IMulticall3.Call3[] memory calls = SpamProposal.buildBatchCall(address(target), count);
        IMulticall3(SpamProposal.MULTICALL3).aggregate3(calls);

        assertEq(AZORIUS.totalProposalCount() - firstProposalId, count, "Expected 1000 proposals submitted");
    }

    function test_spamBlockedAfterThresholdChange() public {
        IAzoriusFork.Transaction[] memory govTxs = GovernanceParametersProposal.buildProposalTransactions();
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), govTxs);

        address spammer = address(0xBAD);
        IAzoriusFork.Transaction[] memory spamTxs =
            SpamProposal.buildProposalTransactions(address(target), abi.encodeCall(MockTarget.setNumber, (999)));

        vm.prank(spammer);
        vm.expectRevert();
        AZORIUS.submitProposal(address(LINEAR_ERC20_VOTING), hex"", spamTxs, _metadata());
    }
}
