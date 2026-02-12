// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";

interface IAzoriusGovernance {
    enum Operation {
        Call,
        DelegateCall
    }

    enum ProposalState {
        None,
        Active,
        Timelocked,
        Executable,
        Executed,
        Expired
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        Operation operation;
    }

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

    function proposalState(uint32 proposalId) external view returns (ProposalState);
}

interface ILinearERC20Voting {
    function vote(uint32 proposalId, uint8 voteType) external;
    function isPassed(uint32 proposalId) external view returns (bool);
}

interface IVotesLike {
    function delegate(address delegatee) external;
}

abstract contract ShutterGovernance is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                GOVERNANCE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address public proposer;
    address[] public voters;

    /*//////////////////////////////////////////////////////////////////////////
                                PROPOSAL VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint32 public proposalId;
    string public metadata;

    /*//////////////////////////////////////////////////////////////////////////
                                   GOVERNANCE CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Azorius contract to submit proposals
    IAzoriusGovernance public constant Azorius =
        IAzoriusGovernance(0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e);

    /// @dev Shutter DAO Voting contract
    ILinearERC20Voting public constant LinearERC20Voting =
        ILinearERC20Voting(0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F);

    /// @dev Shutter Gnosis Safe (Treasury)
    address public constant ShutterGnosis = 0x36bD3044ab68f600f6d3e081056F34f2a58432c4;

    /// @dev Shutter Token
    address public constant ShutterToken = 0xe485E2f1bab389C08721B291f6b59780feC83Fd7;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        _selectFork();

        proposer = _proposer();
        voters = _voters();

        // Label the base contracts
        vm.label(address(Azorius), "Azorius");
        vm.label(address(LinearERC20Voting), "LinearERC20Voting");
        vm.label(ShutterGnosis, "ShutterGnosis");
        vm.label(ShutterToken, "ShutterToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  MAIN TEST FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Executes the full proposal lifecycle.
    function test_proposal() public {
        // Validate if voters achieve quorum by delegating their votes
        _delegateVoters();

        // Generate transactions for the proposal
        IAzoriusGovernance.Transaction[] memory transactions = _prepareTransactions();
        metadata = _metadata();

        // Store parameters to be validated after execution
        _beforeProposal();

        if (!_isProposalSubmitted()) {
            // Submit the proposal
            proposalId = _submitProposal(transactions);
        } else {
            // Get the existing proposal ID
            proposalId = Azorius.totalProposalCount() - 1;
        }

        // Mine block so proposal can be voted on
        vm.roll(block.number + 1);

        // Vote for the proposal
        _voteForProposal(proposalId);

        // Mine blocks until voting period ends
        vm.roll(block.number + 21_600);

        // Check if the proposal passed
        bool passed = LinearERC20Voting.isPassed(proposalId);
        assertTrue(passed, "Proposal did not pass");

        // Execute the proposal
        _executeProposal(proposalId, transactions);

        // Validate if the proposal was executed correctly
        IAzoriusGovernance.ProposalState state = Azorius.proposalState(proposalId);
        assertEq(uint8(state), uint8(IAzoriusGovernance.ProposalState.Executed), "Proposal not executed");

        // Assert parameters modified after execution
        _afterExecution();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GOVERNANCE HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Delegates votes from all voters to themselves.
    function _delegateVoters() internal {
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            IVotesLike(ShutterToken).delegate(voters[i]);
        }
    }

    /// @dev Submits a proposal to the Azorius governor contract.
    function _submitProposal(IAzoriusGovernance.Transaction[] memory transactions) internal returns (uint32) {
        uint32 newProposalId = Azorius.totalProposalCount();

        vm.prank(proposer);
        Azorius.submitProposal(address(LinearERC20Voting), "0x", transactions, metadata);

        return newProposalId;
    }

    /// @dev Votes for a proposal with all voters.
    function _voteForProposal(uint32 _proposalId) internal {
        // NO = 0 | YES = 1 | ABSTAIN = 2
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            LinearERC20Voting.vote(_proposalId, 1);
        }
    }

    /// @dev Executes a proposal.
    function _executeProposal(uint32 _proposalId, IAzoriusGovernance.Transaction[] memory transactions) internal {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusGovernance.Operation[] memory operations
        ) = _prepareTransactionsForExecution(transactions);

        Azorius.executeProposal(_proposalId, targets, values, data, operations);
    }

    /// @dev Prepares transaction arrays expected by Azorius execution.
    function _prepareTransactionsForExecution(IAzoriusGovernance.Transaction[] memory transactions)
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzoriusGovernance.Operation[] memory operations
        )
    {
        uint256 length = transactions.length;

        targets = new address[](length);
        values = new uint256[](length);
        data = new bytes[](length);
        operations = new IAzoriusGovernance.Operation[](length);

        for (uint256 i = 0; i < length; i++) {
            targets[i] = transactions[i].to;
            values[i] = transactions[i].value;
            data[i] = transactions[i].data;
            operations[i] = transactions[i].operation;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  ABSTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Selects the fork for the test.
    function _selectFork() public virtual;

    /// @dev Returns the proposer address.
    function _proposer() public view virtual returns (address) {
        return 0x9Cc9C7F874eD77df06dCd41D95a2C858cd2a2506; // Joseph - default proposer
    }

    /// @dev Returns the array of voters.
    function _voters() public view virtual returns (address[] memory votersArray) {
        // Default: just use ShutterGnosis as voter (has majority of tokens)
        votersArray = new address[](1);
        votersArray[0] = ShutterGnosis;
    }

    /// @dev Prepares the transactions to be submitted in the proposal.
    function _prepareTransactions() internal view virtual returns (IAzoriusGovernance.Transaction[] memory);

    /// @dev Returns the metadata for the proposal.
    function _metadata() public view virtual returns (string memory);

    /// @dev Checks if the proposal is already submitted on-chain.
    function _isProposalSubmitted() public view virtual returns (bool);

    /// @dev Stores state before proposal execution.
    function _beforeProposal() public virtual;

    /// @dev Validates state after proposal execution.
    function _afterExecution() public virtual;
}
