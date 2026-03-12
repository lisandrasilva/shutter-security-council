// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HatsProposalGatingTest
 * @notice Fork test proving the 6-transaction proposal executes and enables
 *         hat-gated proposal creation on Shutter DAO.
 *
 * Proposal transactions:
 * 0. Enable DecentHatsModificationModule on Safe
 * 1. Create role hat via Call to the module
 * 2. Disable DecentHatsModificationModule
 * 3. Deploy LinearERC20VotingWithHatsProposalCreationV1 via ModuleProxyFactory
 * 4. Enable new strategy on Azorius
 * 5. Set old LinearERC20Voting proposer weight to 1B SHU (total supply)
 *
 * Fork block: 24_493_552
 */
import {ShutterGovernanceBaseForkTest} from "./ShutterGovernance.base.t.sol";
import {IAzorius as IAzoriusFork} from "src/interfaces/IAzorius.sol";
import {ILinearERC20Voting} from "src/interfaces/ILinearERC20Voting.sol";
import {HatsProposalGatingProposal} from "src/proposals/HatsProposalGatingProposal.sol";

// ── Interfaces ──────────────────────────────────────────────────────────

interface ISafe {
    function isModuleEnabled(address module) external view returns (bool);
}

interface IAzoriusStrategy {
    function isStrategyEnabled(address strategy) external view returns (bool);
    function isProposer(address _address) external view returns (bool);
}

// ── Test contract ───────────────────────────────────────────────────────

contract HatsProposalGatingTest is ShutterGovernanceBaseForkTest {
    // ── Hat wearers (edit this list to add/remove proposers) ────────────

    function _proposerHatWearers() internal pure virtual returns (address[] memory wearers) {
        wearers = new address[](1);
        wearers[0] = address(0xCAFA);
    }

    // ── Setup ────────────────────────────────────────────────────────────

    function setUp() public virtual override {
        super.setUp();
        vm.label(HatsProposalGatingProposal.DECENT_HATS(), "DecentHats");
        vm.label(HatsProposalGatingProposal.MODULE_PROXY_FACTORY(), "ModuleProxyFactory");
        vm.label(HatsProposalGatingProposal.HATS_VOTING_STRATEGY(), "HatsVotingStrategy");
    }

    // ── Overrides ────────────────────────────────────────────────────────

    function _metadata() internal pure override returns (string memory) {
        return HatsProposalGatingProposal.metadata();
    }

    function _prepareTransactions() internal pure override returns (IAzoriusFork.Transaction[] memory) {
        return HatsProposalGatingProposal.buildProposalTransactions(_proposerHatWearers());
    }

    function _buildStrategyInitializer() internal pure returns (bytes memory) {
        return HatsProposalGatingProposal.buildStrategyInitializer();
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    function _computeProxyAddress(address factory, address impl, bytes memory initializer, uint256 saltNonce)
        internal
        pure
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes memory creationCode =
            abi.encodePacked(hex"602d8060093d393df3363d3d373d3d3d363d73", impl, hex"5af43d82803e903d91602b57fd5bf3");
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), factory, salt, keccak256(creationCode)));
        return address(uint160(uint256(hash)));
    }

    function _executeGovernanceProposal() internal {
        _submitPassAndExecuteProposal(proposer, address(LINEAR_ERC20_VOTING), _prepareTransactions());
    }

    // ── Tests ────────────────────────────────────────────────────────────

    function test_proposalExecutes() public {
        _executeGovernanceProposal();
    }

    function test_create2AddressMatchesPrediction() public pure {
        bytes memory initializer = _buildStrategyInitializer();
        address computed = _computeProxyAddress(
            HatsProposalGatingProposal.MODULE_PROXY_FACTORY(),
            HatsProposalGatingProposal.HATS_VOTING_IMPL(),
            initializer,
            HatsProposalGatingProposal.DEPLOYMENT_SALT()
        );
        assertEq(
            computed,
            HatsProposalGatingProposal.HATS_VOTING_STRATEGY(),
            "Computed CREATE2 address must match expected strategy"
        );
    }

    function test_hatsStrategyEnabled() public {
        _executeGovernanceProposal();

        assertTrue(
            IAzoriusStrategy(address(AZORIUS)).isStrategyEnabled(HatsProposalGatingProposal.HATS_VOTING_STRATEGY()),
            "Hats voting strategy should be enabled on Azorius"
        );
    }

    function test_decentHatsModuleDisabled() public {
        _executeGovernanceProposal();

        assertFalse(
            ISafe(SHUTTER_SAFE).isModuleEnabled(HatsProposalGatingProposal.DECENT_HATS()),
            "DecentHatsModificationModule should be disabled after proposal"
        );
    }

    function test_oldStrategyProposerWeightMaxed() public {
        _executeGovernanceProposal();

        assertEq(
            ILinearERC20Voting(address(LINEAR_ERC20_VOTING)).requiredProposerWeight(),
            1_000_000_000e18,
            "Old strategy proposer weight should be set to total supply"
        );
    }

    function test_hattedUserCanPropose() public {
        _executeGovernanceProposal();

        address recipient = address(0xCAFE);
        uint256 amount = 1 ether;
        uint256 balanceBefore = recipient.balance;

        IAzoriusFork.Transaction[] memory txs = new IAzoriusFork.Transaction[](1);
        txs[0] =
            IAzoriusFork.Transaction({to: recipient, value: amount, data: "", operation: IAzoriusFork.Operation.Call});

        _submitPassAndExecuteProposal(_proposerHatWearers()[0], HatsProposalGatingProposal.HATS_VOTING_STRATEGY(), txs);

        assertEq(recipient.balance, balanceBefore + amount, "ETH transfer should have executed");
    }

    function test_hatEnablesProposalWithoutVotingPower() public {
        _executeGovernanceProposal();

        address nobody = address(0xbeef);

        assertFalse(
            IAzoriusStrategy(address(LINEAR_ERC20_VOTING)).isProposer(nobody),
            "Address without voting power should NOT propose via old strategy"
        );
        assertFalse(
            IAzoriusStrategy(HatsProposalGatingProposal.HATS_VOTING_STRATEGY()).isProposer(nobody),
            "Address without hat should NOT propose via hats strategy"
        );

        vm.mockCall(
            HatsProposalGatingProposal.HATS_PROTOCOL(),
            abi.encodeWithSignature(
                "isWearerOfHat(address,uint256)", nobody, HatsProposalGatingProposal.PROPOSER_HAT_ID()
            ),
            abi.encode(true)
        );

        assertTrue(
            IAzoriusStrategy(HatsProposalGatingProposal.HATS_VOTING_STRATEGY()).isProposer(nobody),
            "Hat wearer should be able to propose via hats strategy"
        );
        assertFalse(
            IAzoriusStrategy(address(LINEAR_ERC20_VOTING)).isProposer(nobody),
            "Hat should NOT grant proposal rights on old strategy"
        );
    }
}
