// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAzorius} from "src/interfaces/IAzorius.sol";
import {HatsProposalGatingProposal} from "src/proposals/HatsProposalGatingProposal.sol";
import {SubmitHatsProposalGatingScript} from "script/SubmitHatsProposalGating.s.sol";

contract SubmitHatsProposalGatingHarness is SubmitHatsProposalGatingScript {
    function exposedWearers() external view returns (address[] memory) {
        return _proposalHatWearers();
    }

    function exposedProposal()
        external
        view
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory metadata)
    {
        return _proposal();
    }
}

contract SubmitHatsProposalGatingTest is Test {
    SubmitHatsProposalGatingHarness internal script;

    function setUp() public {
        script = new SubmitHatsProposalGatingHarness();
    }

    function test_parseWearersFromJsonEnv() public {
        vm.setEnv(
            "PROPOSER_HAT_WEARERS",
            "[\"0x000000000000000000000000000000000000cAFe\",\"0x000000000000000000000000000000000000bEEF\"]"
        );

        address[] memory wearers = script.exposedWearers();

        assertEq(wearers.length, 2);
        assertEq(wearers[0], address(0xCAFE));
        assertEq(wearers[1], address(0xBEEF));
    }

    function test_proposalMatchesCanonicalPayload() public {
        vm.setEnv(
            "PROPOSER_HAT_WEARERS",
            "[\"0x000000000000000000000000000000000000cAFe\",\"0x000000000000000000000000000000000000bEEF\"]"
        );

        address[] memory wearers = script.exposedWearers();
        (address strategy, IAzorius.Transaction[] memory txs, string memory metadata) = script.exposedProposal();

        (address expectedStrategy, IAzorius.Transaction[] memory expectedTxs, string memory expectedMetadata) =
            HatsProposalGatingProposal.buildProposal(wearers);

        assertEq(strategy, expectedStrategy);
        assertEq(metadata, expectedMetadata);
        assertEq(keccak256(abi.encode(txs)), keccak256(abi.encode(expectedTxs)));
    }
}
