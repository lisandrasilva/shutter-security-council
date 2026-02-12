// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Enum, IGuard} from "src/SecurityCouncilAzorius.sol";

contract MockSafe {
    IGuard public guard;

    function setGuard(address newGuard) external {
        guard = IGuard(newGuard);
    }

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        address moduleSender
    ) external payable returns (bool success) {
        IGuard currentGuard = guard;
        if (address(currentGuard) != address(0)) {
            currentGuard.checkTransaction(
                to, value, data, operation, 0, 0, 0, address(0), payable(address(0)), "", moduleSender
            );
        }

        if (operation == Enum.Operation.Call) {
            (success,) = to.call{value: value}(data);
        } else {
            (success,) = to.delegatecall(data);
        }

        if (address(currentGuard) != address(0)) {
            currentGuard.checkAfterExecution(bytes32(0), success);
        }
    }

    receive() external payable {}
}
