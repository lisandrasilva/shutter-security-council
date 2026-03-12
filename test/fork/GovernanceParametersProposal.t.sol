// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title GovernanceParametersProposalTest
 * @notice Fork test for the GovernanceParametersProposal library.
 *         Submits, passes, and executes the 2-tx governance proposal that
 *         hardens execution period and proposer threshold.
 *
 * Transactions:
 *   0. updateExecutionPeriod(50_400)
 *   1. updateRequiredProposerWeight(100_000e18)
 */
import {ShutterGovernanceBaseForkTest} from "./ShutterGovernance.base.t.sol";
import {IAzorius as IAzoriusFork} from "src/interfaces/IAzorius.sol";
import {ILinearERC20Voting} from "src/interfaces/ILinearERC20Voting.sol";
import {GovernanceParametersProposal} from "src/proposals/GovernanceParametersProposal.sol";

contract GovernanceParametersProposalTest is ShutterGovernanceBaseForkTest {
    function _prepareTransactions() internal pure override returns (IAzoriusFork.Transaction[] memory) {
        return GovernanceParametersProposal.buildProposalTransactions();
    }

    function _metadata() internal pure override returns (string memory) {
        return GovernanceParametersProposal.metadata();
    }

    function _executeGovernanceProposal() internal {
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), _prepareTransactions());
    }

    // ── Tests ────────────────────────────────────────────────────────────

    function test_proposalExecutes() public {
        _executeGovernanceProposal();
    }

    function test_executionPeriodUpdated() public {
        _executeGovernanceProposal();
        assertEq(
            IAzoriusFork(address(AZORIUS)).executionPeriod(),
            GovernanceParametersProposal.EXECUTION_PERIOD,
            "Execution period should be 50400"
        );
    }

    function test_proposerWeightUpdated() public {
        _executeGovernanceProposal();
        assertEq(
            ILinearERC20Voting(address(LINEAR_ERC20_VOTING)).requiredProposerWeight(),
            GovernanceParametersProposal.REQUIRED_PROPOSER_WEIGHT,
            "Proposer weight should be 100_000e18"
        );
    }
}
