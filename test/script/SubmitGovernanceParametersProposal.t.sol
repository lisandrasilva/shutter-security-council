// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceParametersProposal} from "src/proposals/GovernanceParametersProposal.sol";
import {SubmitGovernanceParametersProposalScript} from "script/SubmitGovernanceParametersProposal.s.sol";

contract SubmitGovernanceParametersProposalHarness is SubmitGovernanceParametersProposalScript {
    function exposedProposal()
        external
        pure
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata)
    {
        return _proposal();
    }
}

contract SubmitGovernanceParametersProposalTest is Test {
    SubmitGovernanceParametersProposalHarness internal script;

    function setUp() public {
        script = new SubmitGovernanceParametersProposalHarness();
    }

    function test_proposalMatchesCanonicalPayload() public view {
        (address strategy, IAzorius.Transaction[] memory txs, string memory metadata) = script.exposedProposal();

        (address expectedStrategy, IAzorius.Transaction[] memory expectedTxs, string memory expectedMetadata) =
            GovernanceParametersProposal.buildProposal();

        assertEq(strategy, expectedStrategy);
        assertEq(metadata, expectedMetadata);
        assertEq(keccak256(abi.encode(txs)), keccak256(abi.encode(expectedTxs)));
    }
}
