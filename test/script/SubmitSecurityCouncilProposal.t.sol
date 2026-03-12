// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {SecurityCouncilProposal} from "src/proposals/SecurityCouncilProposal.sol";
import {SubmitSecurityCouncilProposalScript} from "script/SubmitSecurityCouncilProposal.s.sol";

contract SubmitSecurityCouncilProposalHarness is SubmitSecurityCouncilProposalScript {
    function exposedProposal()
        external
        view
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata)
    {
        return _proposal();
    }
}

contract SubmitSecurityCouncilProposalTest is Test {
    SubmitSecurityCouncilProposalHarness internal script;

    function setUp() public {
        script = new SubmitSecurityCouncilProposalHarness();
    }

    function test_proposalMatchesCanonicalPayload() public {
        address guardAddress = address(0xBEEF);
        vm.setEnv("GUARD_ADDRESS", vm.toString(guardAddress));

        (address strategy, IAzorius.Transaction[] memory txs, string memory metadata) = script.exposedProposal();

        (address expectedStrategy, IAzorius.Transaction[] memory expectedTxs, string memory expectedMetadata) =
            SecurityCouncilProposal.buildProposal(guardAddress);

        assertEq(strategy, expectedStrategy);
        assertEq(metadata, expectedMetadata);
        assertEq(keccak256(abi.encode(txs)), keccak256(abi.encode(expectedTxs)));
    }
}
