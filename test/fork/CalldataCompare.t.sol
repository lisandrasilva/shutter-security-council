// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HatsProposalGatingTest, IAzoriusFork} from "./HatsProposalGating.t.sol";

/**
 * @title CalldataCompareTest
 * @notice Builds submitProposal calldata from structured Solidity and asserts
 *         byte-for-byte equality with the raw hex captured from the frontend.
 */
contract CalldataCompareTest is HatsProposalGatingTest {
    address constant HAT_WEARER = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;

    function test_calldataMatchesOriginal() public {
        bytes memory original = vm.parseBytes(vm.readFile("test/fork/original_calldata.txt"));

        bytes memory generated = abi.encodeWithSelector(
            IAzoriusFork.submitProposal.selector,
            LINEAR_ERC20_VOTING,
            bytes(""),
            _prepareTransactionsForWearer(HAT_WEARER),
            '{"title":"test","description":"test (hoping this comes to my wallet for me to cancel first lol)"}'
        );

        assertEq(keccak256(generated), keccak256(original), "Calldata mismatch");
    }
}
