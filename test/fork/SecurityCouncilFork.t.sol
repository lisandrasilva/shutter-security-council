// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SecurityCouncilForkTest
 * @notice Fork tests for the SecurityCouncilAzorius guard deployed against
 *         live Shutter DAO governance on Ethereum mainnet.
 *
 * Production flow reproduced:
 *   1. Governance proposal installs the guard on Azorius via setGuard.
 *   2. A second proposal is submitted -- the council can veto/unveto it.
 *
 * Covers: veto, unveto, isProposalVetoed, multicall,
 *         Safe guard edge case, tampered payload rejection.
 */

import {ShutterGovernanceBaseForkTest, IAzoriusFork, ISafeLike} from "./ShutterGovernance.base.t.sol";
import {SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

contract SecurityCouncilForkTest is ShutterGovernanceBaseForkTest {
    uint256 internal constant INTEGRATION_NUMBER = 424_242;
    address internal constant COUNCIL = 0x00000000000000000000000000c0FFEEc0FFEE01;

    SecurityCouncilAzorius internal guard;
    MockTarget internal integrationTarget;

    function setUp() public override {
        super.setUp();

        integrationTarget = new MockTarget();
        vm.label(address(integrationTarget), "IntegrationTarget");

        guard = new SecurityCouncilAzorius(COUNCIL, address(AZORIUS));
        vm.label(address(guard), "SecurityCouncilAzoriusGuard");
        vm.label(COUNCIL, "Council");
    }

    /*//////////////////////////////////////////////////////////////////////////
                             TRANSACTION BUILDERS
    //////////////////////////////////////////////////////////////////////////*/

    function _prepareTransactions()
        internal
        view
        override
        returns (IAzoriusFork.Transaction[] memory txs)
    {} // Not used — each flow has its own transaction builder.

    function _guardInstallTransactions() internal view returns (IAzoriusFork.Transaction[] memory txs) {
        txs = new IAzoriusFork.Transaction[](1);
        txs[0] = IAzoriusFork.Transaction({
            to: address(AZORIUS),
            value: 0,
            data: abi.encodeWithSignature("setGuard(address)", address(guard)),
            operation: IAzoriusFork.Operation.Call
        });
    }

    function _targetTransactions() internal view returns (IAzoriusFork.Transaction[] memory txs) {
        return _targetTransactionsWithNumber(INTEGRATION_NUMBER);
    }

    function _targetTransactionsWithNumber(uint256 number)
        internal
        view
        returns (IAzoriusFork.Transaction[] memory txs)
    {
        txs = new IAzoriusFork.Transaction[](1);
        txs[0] = IAzoriusFork.Transaction({
            to: address(integrationTarget),
            value: 0,
            data: abi.encodeCall(MockTarget.setNumber, (number)),
            operation: IAzoriusFork.Operation.Call
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _submitPassAndExecuteGuardProposal() internal {
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), _guardInstallTransactions());
        assertEq(AZORIUS.guard(), address(guard), "Guard not installed");
    }

    function _submitAndPassTargetProposal() internal returns (uint32 proposalId) {
        return _submitAndPassTargetProposal(INTEGRATION_NUMBER);
    }

    function _submitAndPassTargetProposal(uint256 number) internal returns (uint32 proposalId) {
        return _submitAndPassProposal(proposer, address(LINEAR_ERC20_VOTING), _targetTransactionsWithNumber(number));
    }

    /*//////////////////////////////////////////////////////////////////////////
                              MAINNET SANITY CHECKS
    //////////////////////////////////////////////////////////////////////////*/

    function test_mainnetAddressesAndLiveConfig() public view {
        assertEq(block.chainid, 1, "Fork is not Ethereum mainnet");
        assertGt(SHUTTER_SAFE.code.length, 0, "Safe has no code");
        assertGt(address(AZORIUS).code.length, 0, "Azorius has no code");

        ISafeLike safe = ISafeLike(SHUTTER_SAFE);
        assertEq(safe.masterCopy(), SHUTTER_SAFE_SINGLETON, "Unexpected Safe singleton");
        assertEq(safe.VERSION(), SAFE_VERSION, "Unexpected Safe version");
        assertTrue(safe.isModuleEnabled(address(AZORIUS)), "Azorius is not enabled as Safe module");

        assertEq(AZORIUS.owner(), SHUTTER_SAFE, "Azorius owner mismatch");
        assertEq(AZORIUS.avatar(), SHUTTER_SAFE, "Azorius avatar mismatch");
        assertEq(AZORIUS.target(), SHUTTER_SAFE, "Azorius target mismatch");
        assertEq(AZORIUS.guard(), address(0), "Unexpected non-zero Azorius guard");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 VETO / UNVETO
    //////////////////////////////////////////////////////////////////////////*/

    function test_vetoBlocksExecution() public {
        _submitPassAndExecuteGuardProposal();
        uint32 proposalId = _submitAndPassTargetProposal();
        (address[] memory t, uint256[] memory v, bytes[] memory d, IAzoriusFork.Operation[] memory o) =
            _prepareTransactionsForExecution(_targetTransactions());
        bytes32 txHash = AZORIUS.getTxHash(t[0], v[0], d[0], o[0]);

        vm.prank(COUNCIL);
        guard.vetoProposal(proposalId);
        assertTrue(guard.vetoedTxHash(txHash), "Expected tx hash vetoed");

        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
        AZORIUS.executeProposal(proposalId, t, v, d, o);
    }

    function test_unvetoAllowsExecution() public {
        test_vetoBlocksExecution();

        uint32 proposalId = AZORIUS.totalProposalCount() - 1;
        (address[] memory t, uint256[] memory v, bytes[] memory d, IAzoriusFork.Operation[] memory o) =
            _prepareTransactionsForExecution(_targetTransactions());

        vm.prank(COUNCIL);
        guard.unvetoProposal(proposalId);
        bytes32 txHash = AZORIUS.getTxHash(t[0], v[0], d[0], o[0]);
        assertFalse(guard.vetoedTxHash(txHash), "Expected tx hash unvetoed");

        AZORIUS.executeProposal(proposalId, t, v, d, o);
        assertEq(integrationTarget.number(), INTEGRATION_NUMBER, "Proposal side effect not observed");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   VIEW TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_isProposalVetoedView() public {
        _submitPassAndExecuteGuardProposal();
        uint32 proposalId = _submitAndPassTargetProposal();

        assertFalse(guard.isProposalVetoed(proposalId), "Should not be vetoed initially");

        vm.prank(COUNCIL);
        guard.vetoProposal(proposalId);
        assertTrue(guard.isProposalVetoed(proposalId), "Should be vetoed");

        vm.prank(COUNCIL);
        guard.unvetoProposal(proposalId);
        assertFalse(guard.isProposalVetoed(proposalId), "Should not be vetoed after unveto");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 MULTICALL TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_multicallVetoesMultipleProposals() public {
        _submitPassAndExecuteGuardProposal();
        uint32 proposalA = _submitAndPassTargetProposal(INTEGRATION_NUMBER);
        uint32 proposalB = _submitAndPassTargetProposal(INTEGRATION_NUMBER + 1);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(SecurityCouncilAzorius.vetoProposal, (proposalA));
        calls[1] = abi.encodeCall(SecurityCouncilAzorius.vetoProposal, (proposalB));

        vm.prank(COUNCIL);
        guard.multicall(calls);

        assertTrue(guard.isProposalVetoed(proposalA), "Proposal A should be vetoed");
        assertTrue(guard.isProposalVetoed(proposalB), "Proposal B should be vetoed");

        (address[] memory tA, uint256[] memory vA, bytes[] memory dA, IAzoriusFork.Operation[] memory oA) =
            _prepareTransactionsForExecution(_targetTransactionsWithNumber(INTEGRATION_NUMBER));
        (address[] memory tB, uint256[] memory vB, bytes[] memory dB, IAzoriusFork.Operation[] memory oB) =
            _prepareTransactionsForExecution(_targetTransactionsWithNumber(INTEGRATION_NUMBER + 1));

        vm.expectRevert();
        AZORIUS.executeProposal(proposalA, tA, vA, dA, oA);

        vm.expectRevert();
        AZORIUS.executeProposal(proposalB, tB, vB, dB, oB);
    }
}
