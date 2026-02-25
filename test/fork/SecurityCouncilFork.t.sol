// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SecurityCouncilForkTest
 * @notice Fork tests for the SecurityCouncilAzorius guard deployed against
 *         live Shutter DAO governance on Ethereum mainnet.
 *
 * Covers:
 * - Mainnet address / config sanity checks
 * - Veto blocks execution, unveto restores it
 * - Safe guard vs Azorius guard placement edge case
 * - Tampered execution payload rejection
 * - isProposalVetoed view
 * - multicall batched veto / unveto
 */

import {ShutterGovernanceBaseForkTest, IAzoriusFork, ISafeLike} from "./ShutterGovernance.base.t.sol";
import {SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

contract SecurityCouncilForkTest is ShutterGovernanceBaseForkTest {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal constant INTEGRATION_NUMBER = 424_242;

    /*//////////////////////////////////////////////////////////////////////////
                                  TEST STATE
    //////////////////////////////////////////////////////////////////////////*/

    SecurityCouncilAzorius internal guard;
    MockTarget internal integrationTarget;

    /*//////////////////////////////////////////////////////////////////////////
                                    SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        guard = new SecurityCouncilAzorius(address(this), address(AZORIUS));
        vm.label(address(guard), "SecurityCouncilAzoriusGuard");

        integrationTarget = new MockTarget();
        vm.label(address(integrationTarget), "IntegrationTarget");
    }

    function _prepareTransactions() internal view override returns (IAzoriusFork.Transaction[] memory transactions) {
        transactions = new IAzoriusFork.Transaction[](1);
        transactions[0] = IAzoriusFork.Transaction({
            to: address(integrationTarget),
            value: 0,
            data: abi.encodeCall(MockTarget.setNumber, (INTEGRATION_NUMBER)),
            operation: IAzoriusFork.Operation.Call
        });
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
        assertEq(_safeGuard(), address(0), "Unexpected non-zero Safe guard");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 VETO / UNVETO
    //////////////////////////////////////////////////////////////////////////*/

    function test_vetoBlocksExecution() public {
        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();
        bytes32 txHash = AZORIUS.getTxHash(targets[0], values[0], data[0], operations[0]);

        _installGuardOnAzorius();

        guard.vetoProposal(proposalId);
        assertTrue(guard.vetoedTxHash(txHash), "Expected tx hash vetoed");

        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
        AZORIUS.executeProposal(proposalId, targets, values, data, operations);
    }

    function test_unvetoAllowsExecution() public {
        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();

        _installGuardOnAzorius();

        guard.vetoProposal(proposalId);
        guard.unvetoProposal(proposalId);

        bytes32 txHash = AZORIUS.getTxHash(targets[0], values[0], data[0], operations[0]);
        assertFalse(guard.vetoedTxHash(txHash), "Expected tx hash unvetoed");

        AZORIUS.executeProposal(proposalId, targets, values, data, operations);
        assertEq(integrationTarget.number(), INTEGRATION_NUMBER, "Proposal side effect not observed");
    }

    function test_vetoThenUnvetoFullRoundTrip() public {
        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();
        bytes32 txHash = AZORIUS.getTxHash(targets[0], values[0], data[0], operations[0]);

        _installGuardOnAzorius();

        guard.vetoProposal(proposalId);
        assertTrue(guard.vetoedTxHash(txHash), "Expected tx hash vetoed");

        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
        AZORIUS.executeProposal(proposalId, targets, values, data, operations);

        guard.unvetoProposal(proposalId);
        assertFalse(guard.vetoedTxHash(txHash), "Expected tx hash unvetoed");

        (,, uint32 executionCounterBefore,) = _proposalMeta(proposalId);
        AZORIUS.executeProposal(proposalId, targets, values, data, operations);
        (,, uint32 executionCounterAfter,) = _proposalMeta(proposalId);

        assertEq(executionCounterAfter, executionCounterBefore + uint32(targets.length), "Execution counter mismatch");
        assertEq(integrationTarget.number(), INTEGRATION_NUMBER, "Proposal side effect not observed");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  EDGE CASES
    //////////////////////////////////////////////////////////////////////////*/

    function test_safeGuardOnlyDoesNotBlockModuleExecution() public {
        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();
        bytes32 txHash = AZORIUS.getTxHash(targets[0], values[0], data[0], operations[0]);

        _setSafeGuard(address(guard));
        assertEq(_safeGuard(), address(guard), "Safe guard not set");
        assertEq(AZORIUS.guard(), address(0), "Azorius guard should be unset");

        guard.vetoProposal(proposalId);
        assertTrue(guard.vetoedTxHash(txHash), "Expected tx hash vetoed");

        // Safe 1.3.0 module execution path bypasses Safe guard checks.
        AZORIUS.executeProposal(proposalId, targets, values, data, operations);
        assertEq(integrationTarget.number(), INTEGRATION_NUMBER, "Module execution did not happen");
        assertTrue(guard.vetoedTxHash(txHash), "Veto should still be recorded");
    }

    function test_tamperedPayloadReverts() public {
        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();

        data[0] = abi.encodeCall(MockTarget.setNumber, (INTEGRATION_NUMBER + 1));

        vm.expectRevert();
        AZORIUS.executeProposal(proposalId, targets, values, data, operations);
        assertEq(integrationTarget.number(), 0, "Unexpected side effect after tampered execution");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   VIEW TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_isProposalVetoedView() public {
        uint32 proposalId = _submitAndPassProposal();

        _installGuardOnAzorius();

        assertFalse(guard.isProposalVetoed(proposalId), "Proposal should not be vetoed initially");

        guard.vetoProposal(proposalId);
        assertTrue(guard.isProposalVetoed(proposalId), "Proposal should be vetoed after vetoProposal");

        guard.unvetoProposal(proposalId);
        assertFalse(guard.isProposalVetoed(proposalId), "Proposal should not be vetoed after unvetoProposal");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 MULTICALL TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_multicallVetoUnveto() public {
        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();
        bytes32 txHash = AZORIUS.getTxHash(targets[0], values[0], data[0], operations[0]);

        _installGuardOnAzorius();

        // Batch: veto then unveto in a single multicall
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(SecurityCouncilAzorius.vetoProposal, (proposalId));
        calls[1] = abi.encodeCall(SecurityCouncilAzorius.unvetoProposal, (proposalId));

        guard.multicall(calls);

        assertFalse(guard.vetoedTxHash(txHash), "Tx hash should be unvetoed after multicall veto+unveto");
        assertFalse(guard.isProposalVetoed(proposalId), "Proposal should not be vetoed");

        AZORIUS.executeProposal(proposalId, targets, values, data, operations);
        assertEq(integrationTarget.number(), INTEGRATION_NUMBER, "Execution should succeed after unveto via multicall");
    }

    /*//////////////////////////////////////////////////////////////////////////
                              INTERNAL HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _installGuardOnAzorius() internal {
        vm.prank(SHUTTER_SAFE);
        AZORIUS.setGuard(address(guard));
        assertEq(AZORIUS.guard(), address(guard), "Azorius guard not set");
    }
}
