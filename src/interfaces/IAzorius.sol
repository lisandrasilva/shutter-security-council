// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAzorius {
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

    function timelockPeriod() external view returns (uint32);
    function updateTimelockPeriod(uint32 _timelockPeriod) external;

    function executionPeriod() external view returns (uint32);
    function updateExecutionPeriod(uint32 _executionPeriod) external;

    function enableStrategy(address _strategy) external;

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
