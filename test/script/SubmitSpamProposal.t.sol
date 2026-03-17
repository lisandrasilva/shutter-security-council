// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {SpamProposal} from "src/proposals/SpamProposal.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

contract SubmitSpamProposalTest is Test {
    function test_buildProposalReturnsCorrectStrategy() public pure {
        (address strategy,,) = SpamProposal.buildProposal(0, address(0xdead), hex"");
        assertEq(strategy, GovernanceProposal.LINEAR_ERC20_VOTING());
    }

    function test_buildProposalReturnsSingleTransaction() public pure {
        (, IAzorius.Transaction[] memory txs,) =
            SpamProposal.buildProposal(0, address(0xdead), abi.encodeWithSignature("setNumber(uint256)", 42));

        assertEq(txs.length, 1);
        assertEq(txs[0].to, address(0xdead));
        assertEq(txs[0].value, 0);
        assertEq(txs[0].data, abi.encodeWithSignature("setNumber(uint256)", 42));
    }

    function test_metadataIsWellFormed() public pure {
        for (uint256 i = 0; i < 8; i++) {
            string memory meta = SpamProposal.metadata(i);
            assertGt(bytes(meta).length, 0);
        }
    }
}
