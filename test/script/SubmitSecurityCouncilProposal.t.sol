// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";
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

    function test_proposalTransactionsMatchLibrary() public {
        address guardAddress = address(0xBEEF);
        vm.setEnv("GUARD_ADDRESS", vm.toString(guardAddress));

        (address strategy, IAzorius.Transaction[] memory txs,) = script.exposedProposal();

        IAzorius.Transaction[] memory expectedTxs = SecurityCouncilProposal.buildProposalTransactions(guardAddress);

        assertEq(strategy, GovernanceProposal.LINEAR_ERC20_VOTING());
        assertEq(keccak256(abi.encode(txs)), keccak256(abi.encode(expectedTxs)));
    }

    function test_metadataLoadsDescriptionFromFile() public {
        address guardAddress = address(0xBEEF);
        vm.setEnv("GUARD_ADDRESS", vm.toString(guardAddress));

        (,, string memory metadata) = script.exposedProposal();

        string memory title = vm.parseJsonString(metadata, ".title");
        assertEq(title, "[SECURITY] Implement Security Council to Prevent Governance Attacks");

        string memory description = vm.parseJsonString(metadata, ".description");
        string memory expectedDescription = vm.readFile("docs/comms/proposal-1-security-council-guard.md");
        assertEq(description, expectedDescription);
    }
}
