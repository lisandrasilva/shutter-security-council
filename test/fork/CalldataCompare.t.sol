// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HatsProposalGatingTest, IAzoriusFork} from "./HatsProposalGating.t.sol";

/**
 * @title CalldataCompareTest
 * @notice Builds submitProposal calldata from structured Solidity and asserts
 *         byte-for-byte equality with the raw hex captured from the frontend.
 *
 * The original calldata contains the first 5 transactions of the proposal
 * (before disableStrategy was added). This test validates that our Solidity
 * builders produce identical ABI encoding to the frontend.
 */
contract CalldataCompareTest is HatsProposalGatingTest {
    address constant HAT_WEARER = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;

    function test_calldataMatchesOriginal() public {
        bytes memory original = vm.parseBytes(vm.readFile("test/fork/original_calldata.txt"));

        address[] memory wearers = new address[](1);
        wearers[0] = HAT_WEARER;

        bytes memory generated = abi.encodeWithSelector(
            IAzoriusFork.submitProposal.selector,
            LINEAR_ERC20_VOTING,
            bytes(""),
            _prepareTransactionsForWearers(wearers),
            '{"title":"test","description":"test (hoping this comes to my wallet for me to cancel first lol)"}'
        );

        assertEq(keccak256(generated), keccak256(original), "Calldata mismatch");
    }
}
