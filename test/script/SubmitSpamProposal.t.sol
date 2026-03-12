// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {SpamProposal} from "src/proposals/SpamProposal.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

contract SubmitSpamProposalTest is Test {
    function test_buildProposalReturnsCorrectStrategy() public pure {
        (address strategy,,) = SpamProposal.buildProposal(address(0xdead), hex"");
        assertEq(strategy, GovernanceProposal.LINEAR_ERC20_VOTING());
    }

    function test_buildProposalReturnsSingleTransaction() public pure {
        (, IAzorius.Transaction[] memory txs,) =
            SpamProposal.buildProposal(address(0xdead), abi.encodeWithSignature("setNumber(uint256)", 42));

        assertEq(txs.length, 1);
        assertEq(txs[0].to, address(0xdead));
        assertEq(txs[0].value, 0);
        assertEq(txs[0].data, abi.encodeWithSignature("setNumber(uint256)", 42));
    }

    function test_metadataIsWellFormed() public pure {
        string memory metadata = SpamProposal.metadata();
        assertGt(bytes(metadata).length, 0);
    }
}
