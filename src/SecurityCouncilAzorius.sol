// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.19;

/**
 * Gnosis Safe operation types.
 */
library Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

/**
 * Minimal Guard interface used by Safe/Zodiac.
 */
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

/**
 * Minimal ERC165 interface.
 */
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * Minimal Azorius interface used by this contract.
 */
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

    function getTxHash(address to, uint256 value, bytes memory data, Enum.Operation operation)
        external
        view
        returns (bytes32);
}

/**
 * SecurityCouncilAzorius
 *
 * Guard contract that blocks execution of vetoed Azorius transactions.
 */
contract SecurityCouncilAzorius is IGuard, IERC165 {
    // --- config ---
    address public immutable council;
    address public immutable azorius;

    // --- veto storage ---
    mapping(bytes32 => bool) public vetoedTxHash;

    // --- events ---
    event ProposalVetoed(uint32 indexed proposalId, uint256 txCount);
    event ProposalUnvetoed(uint32 indexed proposalId, uint256 txCount);
    event TxHashVetoed(bytes32 indexed txHash);
    event TxHashUnvetoed(bytes32 indexed txHash);
    event GuardDeployed(address indexed council, address indexed azorius);

    // --- errors ---
    error NotCouncil();
    error AlreadyVetoed(bytes32 txHash);
    error NotVetoed(bytes32 txHash);
    error TransactionVetoed(bytes32 txHash);
    error ZeroAddressCouncil();
    error ZeroAddressAzorius();

    modifier onlyCouncil() {
        if (msg.sender != council) revert NotCouncil();
        _;
    }

    constructor(address _council, address _azorius) {
        if (_council == address(0)) revert ZeroAddressCouncil();
        if (_azorius == address(0)) revert ZeroAddressAzorius();

        council = _council;
        azorius = _azorius;

        emit GuardDeployed(_council, _azorius);
    }

    // -------------------------
    // Council operations
    // -------------------------

    /**
     * Vetoes all txHashes stored on Azorius for `proposalId`.
     * Idempotent by design.
     */
    function vetoProposal(uint32 proposalId) external onlyCouncil {
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

    /**
     * Clears veto status for all txHashes in `proposalId`.
     * Idempotent by design.
     */
    function unvetoProposal(uint32 proposalId) external onlyCouncil {
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

    /**
     * Fine-grained veto controls.
     */
    function vetoTx(bytes32 txHash) external onlyCouncil {
        if (vetoedTxHash[txHash]) revert AlreadyVetoed(txHash);
        vetoedTxHash[txHash] = true;
        emit TxHashVetoed(txHash);
    }

    function unvetoTx(bytes32 txHash) external onlyCouncil {
        if (!vetoedTxHash[txHash]) revert NotVetoed(txHash);
        vetoedTxHash[txHash] = false;
        emit TxHashUnvetoed(txHash);
    }

    /**
     * Batches internal council actions. Reverts atomically if any call fails.
     */
    function multicall(bytes[] calldata calls) external onlyCouncil returns (bytes[] memory results) {
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

    // -------------------------
    // Guard interface
    // -------------------------

    /**
     * Blocks execution if Azorius-computed txHash is vetoed.
     */
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

    function checkAfterExecution(bytes32, bool) external override {}

    // ERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IGuard).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    // -------------------------
    // View helpers
    // -------------------------

    /**
     * Returns true if every tx in the proposal is currently vetoed.
     */
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
        (, txHashes,,,) = IAzorius(azorius).getProposal(proposalId);
    }

    function _revertIfVetoed(address to, uint256 value, bytes calldata data, Enum.Operation operation) internal view {
        bytes32 txHash = IAzorius(azorius).getTxHash(to, value, data, operation);
        if (vetoedTxHash[txHash]) revert TransactionVetoed(txHash);
    }
}
