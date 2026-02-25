// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";

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

    function getTxHash(address to, uint256 value, bytes memory data, Operation operation)
        external
        view
        returns (bytes32);
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

abstract contract ShutterGovernanceBaseForkTest is Test {
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

    /*//////////////////////////////////////////////////////////////////////////
                                  TEST STATE
    //////////////////////////////////////////////////////////////////////////*/

    address internal proposer;
    address[] internal voters;

    function _rpcUrl() internal view returns (string memory rpcUrl) {
        rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) rpcUrl = vm.envOr("RPC_URL", string(""));
    }

    function _forkBlockNumber() internal pure virtual returns (uint256) {
        return 24_493_552;
    }

    function setUp() public virtual {
        string memory rpcUrl = _rpcUrl();
        vm.skip(bytes(rpcUrl).length == 0);

        vm.createSelectFork(rpcUrl, _forkBlockNumber());

        proposer = DEFAULT_PROPOSER;
        voters = _defaultVoters();

        vm.label(address(AZORIUS), "Azorius");
        vm.label(address(LINEAR_ERC20_VOTING), "LinearERC20Voting");
        vm.label(SHUTTER_SAFE, "ShutterSafe");
        vm.label(SHUTTER_TOKEN, "ShutterToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _defaultVoters() internal pure returns (address[] memory votersArray) {
        votersArray = new address[](1);
        votersArray[0] = SHUTTER_SAFE;
    }

    function _prepareTransactions() internal view virtual returns (IAzoriusFork.Transaction[] memory transactions);

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

    function _metadata() internal pure virtual returns (string memory) {
        return "security-council-azorius fork integration test";
    }

    function _submitAndPassProposal() internal returns (uint32 proposalId) {
        return _submitAndPassProposal(proposer, address(LINEAR_ERC20_VOTING), _prepareTransactions());
    }

    function _submitAndPassProposal(address _proposer, address strategy, IAzoriusFork.Transaction[] memory transactions)
        internal
        returns (uint32 proposalId)
    {
        _delegateVoters();

        proposalId = AZORIUS.totalProposalCount();

        vm.prank(_proposer);
        AZORIUS.submitProposal(strategy, hex"", transactions, _metadata());

        vm.roll(block.number + 1);
        _voteOnProposal(proposalId, strategy);
        vm.roll(block.number + VOTING_PERIOD_BLOCKS);

        assertTrue(ILinearERC20VotingFork(strategy).isPassed(proposalId), "Proposal did not pass");

        (uint32 timelockPeriod,,,) = _proposalMeta(proposalId);
        if (timelockPeriod > 0) {
            vm.warp(block.timestamp + timelockPeriod + 1);
        }
    }

    function _submitPassAndExecuteProposal(
        address _proposer,
        address strategy,
        IAzoriusFork.Transaction[] memory transactions
    ) internal {
        uint32 proposalId = _submitAndPassProposal(_proposer, strategy, transactions);

        (address[] memory targets, uint256[] memory values, bytes[] memory data, IAzoriusFork.Operation[] memory ops) =
            _prepareTransactionsForExecution(transactions);

        AZORIUS.executeProposal(proposalId, targets, values, data, ops);
    }

    function _delegateVoters() internal {
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            IVotesFork(SHUTTER_TOKEN).delegate(voters[i]);
        }
    }

    function _voteOnProposal(uint32 proposalId, address strategy) internal {
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            ILinearERC20VotingFork(strategy).vote(proposalId, 1);
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
}
