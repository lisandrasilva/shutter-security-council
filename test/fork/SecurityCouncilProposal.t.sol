// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SecurityCouncilProposalTest
 * @notice Fork test for the SecurityCouncilProposal library.
 *         Submits, passes, and executes the 2-tx governance proposal that installs
 *         the security council guard with a 2-day timelock.
 *
 * Transactions:
 *   0. updateTimelockPeriod(14_400)
 *   1. setGuard(guardAddress)
 */
import {ShutterGovernanceBaseForkTest} from "./ShutterGovernance.base.t.sol";
import {IAzorius as IAzoriusFork} from "src/interfaces/IAzorius.sol";
import {SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {SecurityCouncilProposal} from "src/proposals/SecurityCouncilProposal.sol";

contract SecurityCouncilProposalTest is ShutterGovernanceBaseForkTest {
    address internal constant COUNCIL = 0x00000000000000000000000000c0FFEEc0FFEE01;

    SecurityCouncilAzorius internal guard;

    function setUp() public override {
        super.setUp();

        guard = new SecurityCouncilAzorius(COUNCIL, address(AZORIUS));
        vm.label(address(guard), "SecurityCouncilAzoriusGuard");
        vm.label(COUNCIL, "Council");
    }

    function _prepareTransactions() internal view override returns (IAzoriusFork.Transaction[] memory) {
        return SecurityCouncilProposal.buildProposalTransactions(address(guard));
    }

    function _metadata() internal pure override returns (string memory) {
        return SecurityCouncilProposal.metadata();
    }

    function _executeGovernanceProposal() internal {
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), _prepareTransactions());
    }

    // ── Tests ────────────────────────────────────────────────────────────

    function test_proposalExecutes() public {
        _executeGovernanceProposal();
    }

    function test_timelockUpdated() public {
        _executeGovernanceProposal();
        assertEq(
            IAzoriusFork(address(AZORIUS)).timelockPeriod(),
            SecurityCouncilProposal.TIMELOCK_PERIOD,
            "Timelock period should be 14400"
        );
    }

    function test_guardInstalled() public {
        _executeGovernanceProposal();
        assertEq(AZORIUS.guard(), address(guard), "Guard should be installed on Azorius");
    }

    function test_orderMatters_guardInstalledLast() public {
        _executeGovernanceProposal();

        IAzoriusFork.Transaction[] memory dummyTxs = new IAzoriusFork.Transaction[](1);
        dummyTxs[0] = IAzoriusFork.Transaction({
            to: address(0xdead),
            value: 0,
            data: "",
            operation: IAzoriusFork.Operation.Call
        });

        _delegateVoters();
        uint32 newProposalId = AZORIUS.totalProposalCount();
        vm.prank(proposer);
        AZORIUS.submitProposal(address(LINEAR_ERC20_VOTING), hex"", dummyTxs, _metadata());

        (uint32 timelockPeriod,,,) = _proposalMeta(newProposalId);
        assertEq(timelockPeriod, SecurityCouncilProposal.TIMELOCK_PERIOD, "New proposal should have updated timelock");
    }
}
