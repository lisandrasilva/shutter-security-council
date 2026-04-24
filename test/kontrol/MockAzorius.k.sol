// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Enum, IAzorius} from "src/SecurityCouncilAzorius.sol";
import {KontrolTest} from "test/kontrol/KontrolTest.sol"; 

contract MockAzorius is IAzorius, KontrolTest {
    struct Proposal {
        address strategy;
        uint32 timelockPeriod;
        uint32 executionPeriod;
        uint32 executionCounter;
        bytes32[] txHashes;
    }

    mapping(uint32 => Proposal) internal proposals;

    function setProposal(
        uint32 proposalId,
        bytes32[] memory txHashes,
        address strategy,
        uint32 timelockPeriod,
        uint32 executionPeriod,
        uint32 executionCounter
    ) external {
        Proposal storage proposal = proposals[proposalId];
        proposal.strategy = strategy;
        proposal.timelockPeriod = timelockPeriod;
        proposal.executionPeriod = executionPeriod;
        proposal.executionCounter = executionCounter;

        delete proposal.txHashes;
        uint256 txsLen = txHashes.length;
        for (uint256 i = 0; i < txsLen;) {
            proposal.txHashes.push(txHashes[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Populates the txHashes array of a proposal with symbolic values for use
    ///      in Kontrol symbolic execution proofs.
    ///
    ///      The Solidity storage layout for `proposals[proposalId]` is:
    ///        proposalIdSlot + 0 : packed (strategy, timelockPeriod, executionPeriod, executionCounter)
    ///        proposalIdSlot + 1 : txHashes.length  (dynamic array length)
    ///        keccak256(proposalIdSlot + 1) + i : txHashes[i]  (array element slots)
    ///
    ///      The function builds the array by writing one fresh symbolic bytes32 per
    ///      iteration directly into the element slots. Each iteration continues only
    ///      if kevm.freshBool() returns true, so the symbolic length is unbounded but
    ///      finite on every concrete execution path explored by KEVM. After the loop,
    ///      the accumulated length is written to the length slot so that Solidity array
    ///      reads return a consistent view of the symbolic data.
    function setSymbolicProposal(uint32 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        uint256 proposalIdSlot;
        assembly {
            proposalIdSlot := proposal.slot
        }

        uint256 txsLen;
        for (txsLen = 0; kevm.freshBool();) {
            uint256 txHash = freshUInt256(string(abi.encodePacked("txHash", vm.toString(txsLen))));
            uint256 txHashSlot = uint256(keccak256(abi.encode(proposalIdSlot + 1))) + txsLen;
            _storeUInt256(address(this), txHashSlot, txHash);
            unchecked {
                ++txsLen;
            }
        }
        // Store the length of the txHashes array
        _storeUInt256(address(this), proposalIdSlot + 1, txsLen);
    }


    function getProposalTxHashes(uint32 proposalId)
        external
        view
        override
        returns (bytes32[] memory txHashes)
    {
        Proposal storage proposal = proposals[proposalId];
        uint256 txsLen = proposal.txHashes.length;
        txHashes = new bytes32[](txsLen);
        for (uint256 i = 0; i < txsLen;) {
            txHashes[i] = proposal.txHashes[i];
            unchecked {
                ++i;
            }
        }
    }

    function getProposal(uint32 proposalId)
        external
        view
        override
        returns (
            address strategy,
            bytes32[] memory txHashes,
            uint32 timelockPeriod,
            uint32 executionPeriod,
            uint32 executionCounter
        )
    {
        Proposal storage proposal = proposals[proposalId];
        uint256 txsLen = proposal.txHashes.length;
        txHashes = new bytes32[](txsLen);
        for (uint256 i = 0; i < txsLen;) {
            txHashes[i] = proposal.txHashes[i];
            unchecked {
                ++i;
            }
        }

        return
            (proposal.strategy, txHashes, proposal.timelockPeriod, proposal.executionPeriod, proposal.executionCounter);
    }

    function getTxHash(address to, uint256 value, bytes memory data, Enum.Operation operation)
        external
        pure
        override
        returns (bytes32)
    {
        return _hashTx(to, value, data, operation);
    }

    function hashTx(address to, uint256 value, bytes memory data, Enum.Operation operation)
        external
        pure
        returns (bytes32)
    {
        return _hashTx(to, value, data, operation);
    }

    function _hashTx(address to, uint256 value, bytes memory data, Enum.Operation operation)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(to, value, data, operation));
    }
}
