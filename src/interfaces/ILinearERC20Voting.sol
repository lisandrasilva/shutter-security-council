// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILinearERC20Voting {
    function requiredProposerWeight() external view returns (uint256);
    function updateRequiredProposerWeight(uint256 _requiredProposerWeight) external;
}
