// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockTarget {
    uint256 public number;

    event NumberSet(uint256 newNumber);

    function setNumber(uint256 newNumber) external payable {
        number = newNumber;
        emit NumberSet(newNumber);
    }
}
