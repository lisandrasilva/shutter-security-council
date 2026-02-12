// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

interface IAzoriusFork {
    enum Operation {
        Call,
        DelegateCall
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        Operation operation;
    }

    function owner() external view returns (address);
    function avatar() external view returns (address);
    function target() external view returns (address);
    function guard() external view returns (address);
    function setGuard(address _guard) external;

    function totalProposalCount() external view returns (uint32);

    function submitProposal(
        address strategy,
        bytes calldata metadataData,
        Transaction[] calldata transactions,
        string calldata metadata
    ) external;

    function executeProposal(
        uint32 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata data,
        Operation[] calldata operations
    ) external;

    function getProposal(uint32 proposalId)
        external
        view
        returns (
            address strategy,
            bytes32[] memory txHashes,
            uint32 timelockPeriod,
            uint32 executionPeriod,
            uint32 executionCounter
        );

    function getTxHash(address to, uint256 value, bytes memory data, Operation operation) external view returns (bytes32);
}

interface ILinearERC20VotingFork {
    function vote(uint32 proposalId, uint8 voteType) external;
    function isPassed(uint32 proposalId) external view returns (bool);
}

interface IVotesFork {
    function delegate(address delegatee) external;
}

interface ISafeLike {
    function masterCopy() external view returns (address);
    function VERSION() external view returns (string memory);
    function isModuleEnabled(address module) external view returns (bool);
}

contract ShutterGovernanceBaseForkTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                MAINNET CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    IAzoriusFork internal constant AZORIUS = IAzoriusFork(0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e);
    ILinearERC20VotingFork internal constant LINEAR_ERC20_VOTING =
        ILinearERC20VotingFork(0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F);
    address internal constant SHUTTER_SAFE = 0x36bD3044ab68f600f6d3e081056F34f2a58432c4;
    address internal constant SHUTTER_SAFE_SINGLETON = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
    address internal constant SHUTTER_TOKEN = 0xe485E2f1bab389C08721B291f6b59780feC83Fd7;
    address internal constant DEFAULT_PROPOSER = 0x9Cc9C7F874eD77df06dCd41D95a2C858cd2a2506;
    string internal constant SAFE_VERSION = "1.3.0";
    uint256 internal constant VOTING_PERIOD_BLOCKS = 21_600;
    uint256 internal constant INTEGRATION_NUMBER = 424_242;

    // keccak256("guard_manager.guard.address") from Safe GuardManager.
    bytes32 internal constant SAFE_GUARD_STORAGE_SLOT =
        0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    /*//////////////////////////////////////////////////////////////////////////
                                  TEST STATE
    //////////////////////////////////////////////////////////////////////////*/

    bool internal forkReady;
    address internal proposer;
    address[] internal voters;
    SecurityCouncilAzorius internal guard;
    MockTarget internal integrationTarget;

    function setUp() public {
        proposer = DEFAULT_PROPOSER;
        voters = _defaultVoters();

        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            rpcUrl = vm.envOr("RPC_URL", string(""));
        }
        if (bytes(rpcUrl).length == 0) {
            emit log("Skipping fork tests: set MAINNET_RPC_URL (or RPC_URL).");
            return;
        }

        vm.createSelectFork(rpcUrl);
        forkReady = true;

        vm.label(address(AZORIUS), "Azorius");
        vm.label(address(LINEAR_ERC20_VOTING), "LinearERC20Voting");
        vm.label(SHUTTER_SAFE, "ShutterSafe");
        vm.label(SHUTTER_TOKEN, "ShutterToken");

        // Use this test contract as council for fork integration checks.
        guard = new SecurityCouncilAzorius(address(this), address(AZORIUS));
        vm.label(address(guard), "SecurityCouncilAzoriusTestGuard");

        // Integration target used to assert real execution effects through Azorius -> Safe.
        integrationTarget = new MockTarget();
        vm.label(address(integrationTarget), "IntegrationTarget");
    }

    function test_mainnetAddressesAndLiveConfig() public view {
        if (!forkReady) return;

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

    function test_completeForkIntegration_moduleGuardVetoBlocksAndUnvetoAllows() public {
        if (!forkReady) return;

        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();
        bytes32 txHash = AZORIUS.getTxHash(targets[0], values[0], data[0], operations[0]);

        // Set guard on Azorius module (actual execution path for proposals).
        vm.prank(SHUTTER_SAFE);
        AZORIUS.setGuard(address(guard));
        assertEq(AZORIUS.guard(), address(guard), "Azorius guard not set");

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

    function test_edgeCase_safeGuardOnlyDoesNotBlockModuleExecution() public {
        if (!forkReady) return;

        uint32 proposalId = _submitAndPassProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        ) = _proposalExecutionArrays();
        bytes32 txHash = AZORIUS.getTxHash(targets[0], values[0], data[0], operations[0]);

        // Misconfiguration edge case: Safe guard is set, but Azorius module guard remains unset.
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

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _defaultVoters() internal pure returns (address[] memory votersArray) {
        votersArray = new address[](1);
        votersArray[0] = SHUTTER_SAFE;
    }

    function _prepareTransactions() internal view returns (IAzoriusFork.Transaction[] memory transactions) {
        transactions = new IAzoriusFork.Transaction[](1);
        transactions[0] = IAzoriusFork.Transaction({
            to: address(integrationTarget),
            value: 0,
            data: abi.encodeCall(MockTarget.setNumber, (INTEGRATION_NUMBER)),
            operation: IAzoriusFork.Operation.Call
        });
    }

    function _proposalExecutionArrays()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        )
    {
        IAzoriusFork.Transaction[] memory transactions = _prepareTransactions();
        return _prepareTransactionsForExecution(transactions);
    }

    function _metadata() internal pure returns (string memory) {
        return "security-council-azorius fork integration test";
    }

    function _submitAndPassProposal() internal returns (uint32 proposalId) {
        _delegateVoters();

        IAzoriusFork.Transaction[] memory transactions = _prepareTransactions();
        proposalId = AZORIUS.totalProposalCount();

        vm.prank(proposer);
        AZORIUS.submitProposal(address(LINEAR_ERC20_VOTING), hex"", transactions, _metadata());

        vm.roll(block.number + 1);
        _voteForProposal(proposalId);
        vm.roll(block.number + VOTING_PERIOD_BLOCKS);

        bool passed = LINEAR_ERC20_VOTING.isPassed(proposalId);
        assertTrue(passed, "Proposal did not pass");

        // If a timelock is configured, advance timestamp to post-timelock.
        (uint32 timelockPeriod,,,) = _proposalMeta(proposalId);
        if (timelockPeriod > 0) {
            vm.warp(block.timestamp + timelockPeriod + 1);
        }
    }

    function _delegateVoters() internal {
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            IVotesFork(SHUTTER_TOKEN).delegate(voters[i]);
        }
    }

    function _voteForProposal(uint32 proposalId) internal {
        // NO = 0 | YES = 1 | ABSTAIN = 2
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            LINEAR_ERC20_VOTING.vote(proposalId, 1);
        }
    }

    function _prepareTransactionsForExecution(IAzoriusFork.Transaction[] memory transactions)
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusFork.Operation[] memory operations
        )
    {
        uint256 length = transactions.length;

        targets = new address[](length);
        values = new uint256[](length);
        data = new bytes[](length);
        operations = new IAzoriusFork.Operation[](length);

        for (uint256 i = 0; i < length; i++) {
            targets[i] = transactions[i].to;
            values[i] = transactions[i].value;
            data[i] = transactions[i].data;
            operations[i] = transactions[i].operation;
        }
    }

    function _proposalMeta(uint32 proposalId)
        internal
        view
        returns (uint32 timelockPeriod, uint32 executionPeriod, uint32 executionCounter, uint32 txCount)
    {
        bytes32[] memory txHashes;
        (, txHashes, timelockPeriod, executionPeriod, executionCounter) = AZORIUS.getProposal(proposalId);
        txCount = uint32(txHashes.length);
    }

    function _setSafeGuard(address newGuard) internal {
        vm.store(SHUTTER_SAFE, SAFE_GUARD_STORAGE_SLOT, bytes32(uint256(uint160(newGuard))));
    }

    function _safeGuard() internal view returns (address) {
        return address(uint160(uint256(vm.load(SHUTTER_SAFE, SAFE_GUARD_STORAGE_SLOT))));
    }
}
