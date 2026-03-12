// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title FullLifecycleTest
 * @notice End-to-end fork test executing all 5 on-chain steps in sequence:
 *
 *   1. Deploy SecurityCouncilAzorius guard
 *   2. Submit + execute guard install proposal (timelock + guard)
 *   3. Submit + execute governance parameters proposal (execution period + proposer weight)
 *   4. Attempt spam attack (verify blocked by new 100K SHU threshold)
 *   5. Submit + execute hats proposal gating (through timelock + guard pipeline)
 */
import {ShutterGovernanceBaseForkTest} from "./ShutterGovernance.base.t.sol";
import {IAzorius as IAzoriusFork} from "src/interfaces/IAzorius.sol";
import {ILinearERC20Voting} from "src/interfaces/ILinearERC20Voting.sol";
import {SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {SecurityCouncilProposal} from "src/proposals/SecurityCouncilProposal.sol";
import {GovernanceParametersProposal} from "src/proposals/GovernanceParametersProposal.sol";
import {SpamProposal} from "src/proposals/SpamProposal.sol";
import {HatsProposalGatingProposal} from "src/proposals/HatsProposalGatingProposal.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

interface IAzoriusStrategy {
    function isStrategyEnabled(address strategy) external view returns (bool);
}

contract FullLifecycleTest is ShutterGovernanceBaseForkTest {
    address internal constant COUNCIL = 0x00000000000000000000000000c0FFEEc0FFEE01;

    SecurityCouncilAzorius internal guard;
    MockTarget internal spamTarget;

    function _prepareTransactions() internal view override returns (IAzoriusFork.Transaction[] memory) {}

    function _proposerHatWearers() internal pure returns (address[] memory wearers) {
        wearers = new address[](1);
        wearers[0] = address(0xCAFA);
    }

    function setUp() public override {
        super.setUp();

        // Step 1: Deploy guard
        guard = new SecurityCouncilAzorius(COUNCIL, address(AZORIUS));
        vm.label(address(guard), "SecurityCouncilAzoriusGuard");
        vm.label(COUNCIL, "Council");

        spamTarget = new MockTarget();
        vm.label(address(spamTarget), "SpamTarget");
    }

    function test_fullLifecycle() public {
        // ── Step 2: Security Council proposal (timelock + guard) ─────────

        IAzoriusFork.Transaction[] memory scTxs = SecurityCouncilProposal.buildProposalTransactions(address(guard));
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), scTxs);

        assertEq(AZORIUS.guard(), address(guard), "Guard should be installed");
        assertEq(
            IAzoriusFork(address(AZORIUS)).timelockPeriod(),
            SecurityCouncilProposal.TIMELOCK_PERIOD,
            "Timelock should be 14400"
        );

        // ── Step 3: Governance parameters proposal ───────────────────────

        IAzoriusFork.Transaction[] memory govTxs = GovernanceParametersProposal.buildProposalTransactions();
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), govTxs);

        assertEq(
            IAzoriusFork(address(AZORIUS)).executionPeriod(),
            GovernanceParametersProposal.EXECUTION_PERIOD,
            "Execution period should be 50400"
        );
        assertEq(
            ILinearERC20Voting(address(LINEAR_ERC20_VOTING)).requiredProposerWeight(),
            GovernanceParametersProposal.REQUIRED_PROPOSER_WEIGHT,
            "Proposer weight should be 100K SHU"
        );

        // ── Step 4: Spam attack (should be blocked) ─────────────────────

        address spammer = address(0xBAD);
        IAzoriusFork.Transaction[] memory spamTxs = SpamProposal.buildProposalTransactions(
            address(spamTarget), abi.encodeCall(MockTarget.setNumber, (999))
        );

        vm.prank(spammer);
        vm.expectRevert();
        AZORIUS.submitProposal(address(LINEAR_ERC20_VOTING), hex"", spamTxs, SpamProposal.metadata());

        // ── Step 5: Hats proposal gating ─────────────────────────────────
        // After step 3, proposer threshold is 100K SHU. The Safe has enough weight.
        proposer = SHUTTER_SAFE;

        IAzoriusFork.Transaction[] memory hatsTxs =
            HatsProposalGatingProposal.buildProposalTransactions(_proposerHatWearers());
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), hatsTxs);

        assertTrue(
            IAzoriusStrategy(address(AZORIUS)).isStrategyEnabled(HatsProposalGatingProposal.HATS_VOTING_STRATEGY()),
            "Hats voting strategy should be enabled"
        );

        assertEq(
            ILinearERC20Voting(address(LINEAR_ERC20_VOTING)).requiredProposerWeight(),
            1_000_000_000e18,
            "Old strategy proposer weight should be set to total supply"
        );
    }
}
