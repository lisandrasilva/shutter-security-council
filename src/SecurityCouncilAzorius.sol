// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.19;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title Enum - Gnosis Safe operation types.
library Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

/// @title IGuard - Minimal Guard interface used by Safe/Zodiac.
interface IGuard {
    function checkTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures,
        address msgSender
    ) external;

    function checkAfterExecution(bytes32 txHash, bool success) external;
}

/// @title IERC165 - Minimal ERC165 interface.
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/// @title IAzorius - Minimal Azorius interface used by this contract.
interface IAzorius {
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

    function getProposalTxHashes(uint32 proposalId) external view returns (bytes32[] memory txHashes);

    function getTxHash(address to, uint256 value, bytes memory data, Enum.Operation operation)
        external
        view
        returns (bytes32);
}

/// @title SecurityCouncilAzorius
/// @notice IGuard-compatible veto guard for Azorius proposal transactions.
/// @dev Veto state is global by txHash, not scoped by proposalId. If two proposals share
///      a txHash, vetoing either one blocks both execution paths until unvetoed.
///      Must be installed on the Azorius module via `Azorius.setGuard(address)`, not on the Safe.
contract SecurityCouncilAzorius is IGuard, IERC165, Ownable {
    // --- config ---

    /// @notice Address of the Azorius governance module.
    address public immutable azorius;

    // --- veto storage ---

    /// @notice Whether a given Azorius txHash is currently vetoed.
    mapping(bytes32 => bool) public vetoedTxHash;

    // --- events ---

    /// @notice Emitted when `vetoProposal` is called.
    /// @param proposalId The Azorius proposal whose txHashes were vetoed.
    /// @param txCount Number of txHashes that actually transitioned to vetoed.
    event ProposalVetoed(uint32 indexed proposalId, uint256 txCount);

    /// @notice Emitted when `unvetoProposal` is called.
    /// @param proposalId The Azorius proposal whose txHashes were unvetoed.
    /// @param txCount Number of txHashes that actually transitioned to unvetoed.
    event ProposalUnvetoed(uint32 indexed proposalId, uint256 txCount);

    /// @notice Emitted when a single txHash transitions from unvetoed to vetoed.
    event TxHashVetoed(bytes32 indexed txHash);

    /// @notice Emitted when a single txHash transitions from vetoed to unvetoed.
    event TxHashUnvetoed(bytes32 indexed txHash);

    /// @notice Emitted once at construction.
    event GuardDeployed(address indexed council, address indexed azorius);

    // --- errors ---

    error AlreadyVetoed(bytes32 txHash);
    error NotVetoed(bytes32 txHash);
    error TransactionVetoed(bytes32 txHash);
    error ZeroAddressAzorius();
    error RenounceOwnershipDisabled();

    /// @param _council Address authorized to veto/unveto via `owner()`.
    /// @param _azorius Azorius governance module address (immutable after deployment).
    constructor(address _council, address _azorius) Ownable(_council) {
        if (_azorius == address(0)) revert ZeroAddressAzorius();

        azorius = _azorius;

        emit GuardDeployed(_council, _azorius);
    }

    // -------------------------
    // Council operations
    // -------------------------

    /// @notice Vetoes all txHashes stored on Azorius for `proposalId`. Idempotent.
    /// @param proposalId The Azorius proposal to veto.
    function vetoProposal(uint32 proposalId) external onlyOwner {
        bytes32[] memory txs = _getProposalTxHashes(proposalId);
        uint256 txsLen = txs.length;
        uint256 vetoedCount;

        for (uint256 i = 0; i < txsLen;) {
            bytes32 txHash = txs[i];
            if (!vetoedTxHash[txHash]) {
                vetoedTxHash[txHash] = true;
                emit TxHashVetoed(txHash);
                unchecked {
                    ++vetoedCount;
                }
            }

            unchecked {
                ++i;
            }
        }

        emit ProposalVetoed(proposalId, vetoedCount);
    }

    /// @notice Clears veto status for all txHashes in `proposalId`. Idempotent.
    /// @param proposalId The Azorius proposal to unveto.
    function unvetoProposal(uint32 proposalId) external onlyOwner {
        bytes32[] memory txs = _getProposalTxHashes(proposalId);
        uint256 txsLen = txs.length;
        uint256 unvetoedCount;

        for (uint256 i = 0; i < txsLen;) {
            bytes32 txHash = txs[i];
            if (vetoedTxHash[txHash]) {
                vetoedTxHash[txHash] = false;
                emit TxHashUnvetoed(txHash);
                unchecked {
                    ++unvetoedCount;
                }
            }

            unchecked {
                ++i;
            }
        }

        emit ProposalUnvetoed(proposalId, unvetoedCount);
    }

    /// @notice Vetoes a single txHash. Reverts if already vetoed.
    /// @param txHash The Azorius transaction hash to veto.
    function vetoTx(bytes32 txHash) external onlyOwner {
        if (vetoedTxHash[txHash]) revert AlreadyVetoed(txHash);
        vetoedTxHash[txHash] = true;
        emit TxHashVetoed(txHash);
    }

    /// @notice Unvetoes a single txHash. Reverts if not currently vetoed.
    /// @param txHash The Azorius transaction hash to unveto.
    function unvetoTx(bytes32 txHash) external onlyOwner {
        if (!vetoedTxHash[txHash]) revert NotVetoed(txHash);
        vetoedTxHash[txHash] = false;
        emit TxHashUnvetoed(txHash);
    }

    /// @notice Batches internal council actions atomically via delegatecall.
    /// @dev Reverts with the original error if any subcall fails.
    /// @param calls ABI-encoded function calls to execute on this contract.
    /// @return results Return data from each subcall.
    function multicall(bytes[] calldata calls) external onlyOwner returns (bytes[] memory results) {
        uint256 callsLen = calls.length;
        results = new bytes[](callsLen);

        for (uint256 i = 0; i < callsLen;) {
            (bool ok, bytes memory returnData) = address(this).delegatecall(calls[i]);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(returnData, 0x20), mload(returnData))
                }
            }
            results[i] = returnData;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Disabled to avoid leaving the guard without a council owner.
    function renounceOwnership() public view override onlyOwner {
        revert RenounceOwnershipDisabled();
    }

    // -------------------------
    // Guard interface
    // -------------------------

    /// @notice Blocks execution if the Azorius-computed txHash is vetoed.
    /// @dev Called by the Azorius module before executing a proposal transaction.
    function checkTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes calldata,
        address
    ) external view override {
        _revertIfVetoed(to, value, data, operation);
    }

    /// @notice No-op. No post-execution validation is needed for veto enforcement.
    function checkAfterExecution(bytes32, bool) external override {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IGuard).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    // -------------------------
    // View helpers
    // -------------------------

    /// @notice Returns true if every txHash in the proposal is currently vetoed.
    /// @dev Returns false for proposals with zero txHashes.
    /// @param proposalId The Azorius proposal to check.
    /// @return True if all txHashes are vetoed.
    function isProposalVetoed(uint32 proposalId) external view returns (bool) {
        bytes32[] memory txs = _getProposalTxHashes(proposalId);
        uint256 txsLen = txs.length;
        if (txsLen == 0) return false;

        for (uint256 i = 0; i < txsLen;) {
            if (!vetoedTxHash[txs[i]]) return false;
            unchecked {
                ++i;
            }
        }
        return true;
    }

    // -------------------------
    // Internal helpers
    // -------------------------

    function _getProposalTxHashes(uint32 proposalId) internal view returns (bytes32[] memory txHashes) {
        txHashes = IAzorius(azorius).getProposalTxHashes(proposalId);
    }

    function _revertIfVetoed(address to, uint256 value, bytes calldata data, Enum.Operation operation) internal view {
        bytes32 txHash = IAzorius(azorius).getTxHash(to, value, data, operation);
        if (vetoedTxHash[txHash]) revert TransactionVetoed(txHash);
    }
}
