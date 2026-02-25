// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HatsProposalGatingTest
 * @notice Fork test proving the 5-transaction proposal executes and enables
 *         hat-gated proposal creation on Shutter DAO.
 *
 * Proposal transactions:
 * 0. Enable DecentHatsModificationModule on Safe
 * 1. Create role hat via Call to the module
 * 2. Disable DecentHatsModificationModule
 * 3. Deploy LinearERC20VotingWithHatsProposalCreationV1 via ModuleProxyFactory
 * 4. Enable new strategy on Azorius
 * 5. Disable old LinearERC20Voting strategy on Azorius
 *
 * Fork block: 24_493_552
 */
import {ShutterGovernanceBaseForkTest, IAzoriusFork} from "./ShutterGovernance.base.t.sol";

// ── Interfaces ──────────────────────────────────────────────────────────

interface ISafe {
    function isModuleEnabled(address module) external view returns (bool);
}

interface IAzoriusStrategy {
    function isStrategyEnabled(address strategy) external view returns (bool);
    function isProposer(address _address) external view returns (bool);
}

// ── Struct definitions matching DecentHatsModuleUtils ABI ───────────────

struct Timestamps {
    uint40 start;
    uint40 cliff;
    uint40 end;
}

struct Broker {
    address account;
    uint256 fee;
}

struct SablierStreamParams {
    address sablier;
    address sender;
    address asset;
    Timestamps timestamps;
    Broker broker;
    uint128 totalAmount;
    bool cancelable;
    bool transferable;
}

struct HatParams {
    address wearer;
    string details;
    string imageURI;
    SablierStreamParams[] sablierStreamsParams;
    uint128 termEndDateTs;
    uint32 maxSupply;
    bool isMutable;
}

struct CreateRoleHatsParams {
    address hatsProtocol;
    address erc6551Registry;
    address hatsAccountImplementation;
    uint256 topHatId;
    address topHatAccount;
    address keyValuePairs;
    address hatsModuleFactory;
    address hatsElectionsEligibilityImplementation;
    uint256 adminHatId;
    HatParams[] hats;
}

interface IDecentHatsModificationModule {
    function createRoleHats(CreateRoleHatsParams calldata roleHatsParams) external;
}

// ── Test contract ───────────────────────────────────────────────────────

contract HatsProposalGatingTest is ShutterGovernanceBaseForkTest {
    // ── Constants ────────────────────────────────────────────────────────

    address constant DECENT_HATS = 0x9755dD7E27E90b4fC00E50EC14DD2D08a79064d3;
    address constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    address constant HATS_VOTING_IMPL = 0x065bDFeE6d7b70b00bbF629aF76362fcDc693e04;
    address constant HATS_PROTOCOL = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
    address constant HATS_VOTING_STRATEGY = 0x7FF645b803FF3Bc890e3568B503BC1F37d32Edd1;

    uint256 constant TOP_HAT_ID = 0x0000004000000000000000000000000000000000000000000000000000000000;
    uint256 constant ADMIN_HAT_ID = 0x0000004000010000000000000000000000000000000000000000000000000000;
    uint256 constant PROPOSER_HAT_ID = 0x0000004000010002000000000000000000000000000000000000000000000000;

    address constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address constant HATS_ACCOUNT_IMPL = 0xfEf83A660b7C10a3EdaFdCF62DEee1fD8a875D29;
    address constant TOP_HAT_ACCOUNT = 0xC30Ed08466e2A713D6567DAB84468ecE6A455f1b;
    address constant KEY_VALUE_PAIRS = 0x535B64f9Ef529Ac8B34Ac7273033bBE67B34f131;
    address constant HATS_MODULE_FACTORY = 0x0a3f85fa597B6a967271286aA0724811acDF5CD9;
    address constant HATS_ELECTIONS_IMPL = 0xd3b916a8F0C4f9D1d5B6Af29c3C012dbd4f3149E;

    uint256 constant DEPLOYMENT_SALT = 0xb3b402edfcc21f484f1f5018c55461995d61d0f5ca5b5fada2e0354e33001c07;
    address constant LIGHT_ACCOUNT_FACTORY = 0x0000000000400CdFef5E2714E63d8040b700BC24;

    // ── Hat wearers (edit this list to add/remove proposers) ────────────

    function _proposerHatWearers() internal pure virtual returns (address[] memory wearers) {
        wearers = new address[](1);
        wearers[0] = address(0xCAFA);
    }

    // ── Setup ────────────────────────────────────────────────────────────

    function setUp() public override {
        super.setUp();
        vm.label(DECENT_HATS, "DecentHats");
        vm.label(MODULE_PROXY_FACTORY, "ModuleProxyFactory");
        vm.label(HATS_VOTING_STRATEGY, "HatsVotingStrategy");
    }

    // ── Overrides ────────────────────────────────────────────────────────

    function _metadata() internal pure override returns (string memory) {
        return
        '{"title":"Hats Protocol Proposal Gating","description":"Enable hat-gated proposal creation for Shutter DAO governance"}';
    }

    function _prepareTransactions() internal pure override returns (IAzoriusFork.Transaction[] memory) {
        IAzoriusFork.Transaction[] memory baseTxs = _prepareTransactionsForWearers(_proposerHatWearers());

        IAzoriusFork.Transaction[] memory txs = new IAzoriusFork.Transaction[](baseTxs.length + 1);
        for (uint256 i = 0; i < baseTxs.length; i++) {
            txs[i] = baseTxs[i];
        }

        txs[baseTxs.length] = IAzoriusFork.Transaction({
            to: address(AZORIUS),
            value: 0,
            data: abi.encodeWithSignature(
                "disableStrategy(address,address)", HATS_VOTING_STRATEGY, address(LINEAR_ERC20_VOTING)
            ),
            operation: IAzoriusFork.Operation.Call
        });

        return txs;
    }

    function _prepareTransactionsForWearers(address[] memory wearers)
        internal
        pure
        returns (IAzoriusFork.Transaction[] memory txs)
    {
        txs = new IAzoriusFork.Transaction[](5);

        txs[0] = IAzoriusFork.Transaction({
            to: SHUTTER_SAFE,
            value: 0,
            data: abi.encodeWithSignature("enableModule(address)", DECENT_HATS),
            operation: IAzoriusFork.Operation.Call
        });

        txs[1] = IAzoriusFork.Transaction({
            to: DECENT_HATS,
            value: 0,
            data: _buildCreateRoleHatCalldata(wearers),
            operation: IAzoriusFork.Operation.Call
        });

        txs[2] = IAzoriusFork.Transaction({
            to: SHUTTER_SAFE,
            value: 0,
            data: abi.encodeWithSignature("disableModule(address,address)", address(0x1), DECENT_HATS),
            operation: IAzoriusFork.Operation.Call
        });

        txs[3] = IAzoriusFork.Transaction({
            to: MODULE_PROXY_FACTORY,
            value: 0,
            data: abi.encodeWithSignature(
                "deployModule(address,bytes,uint256)", HATS_VOTING_IMPL, _buildStrategyInitializer(), DEPLOYMENT_SALT
            ),
            operation: IAzoriusFork.Operation.Call
        });

        txs[4] = IAzoriusFork.Transaction({
            to: address(AZORIUS),
            value: 0,
            data: abi.encodeWithSignature("enableStrategy(address)", HATS_VOTING_STRATEGY),
            operation: IAzoriusFork.Operation.Call
        });
    }

    // ── Calldata builders ───────────────────────────────────────────────

    function _buildCreateRoleHatCalldata(address wearer) internal pure returns (bytes memory) {
        address[] memory wearers = new address[](1);
        wearers[0] = wearer;
        return _buildCreateRoleHatCalldata(wearers);
    }

    function _buildCreateRoleHatCalldata(address[] memory wearers) internal pure returns (bytes memory) {
        HatParams[] memory hats = new HatParams[](wearers.length);
        for (uint256 i = 0; i < wearers.length; i++) {
            hats[i] = HatParams({
                wearer: wearers[i],
                details: "ipfs://QmXN9tFHPL6VjqrpTZ6cEnXz1ULpeiwTPVUZ1oTdZJK51s",
                imageURI: "",
                sablierStreamsParams: new SablierStreamParams[](0),
                termEndDateTs: 0,
                maxSupply: 1,
                isMutable: true
            });
        }

        CreateRoleHatsParams memory params = CreateRoleHatsParams({
            hatsProtocol: HATS_PROTOCOL,
            erc6551Registry: ERC6551_REGISTRY,
            hatsAccountImplementation: HATS_ACCOUNT_IMPL,
            topHatId: TOP_HAT_ID,
            topHatAccount: TOP_HAT_ACCOUNT,
            keyValuePairs: KEY_VALUE_PAIRS,
            hatsModuleFactory: HATS_MODULE_FACTORY,
            hatsElectionsEligibilityImplementation: HATS_ELECTIONS_IMPL,
            adminHatId: ADMIN_HAT_ID,
            hats: hats
        });

        return abi.encodeWithSelector(IDecentHatsModificationModule.createRoleHats.selector, params);
    }

    function _buildStrategyInitializer() internal pure returns (bytes memory) {
        uint256[] memory whitelistedHats = new uint256[](1);
        whitelistedHats[0] = PROPOSER_HAT_ID;

        bytes memory initParams = abi.encode(
            SHUTTER_SAFE,
            SHUTTER_TOKEN,
            address(AZORIUS),
            uint32(21600), // votingPeriod (~3 days in blocks)
            uint256(30000), // quorumNumerator (3%)
            uint256(500000), // basisNumerator (50% to pass)
            HATS_PROTOCOL,
            whitelistedHats,
            LIGHT_ACCOUNT_FACTORY
        );

        return abi.encodeWithSelector(bytes4(keccak256("setUp(bytes)")), initParams);
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
        address computed = _computeProxyAddress(MODULE_PROXY_FACTORY, HATS_VOTING_IMPL, initializer, DEPLOYMENT_SALT);
        assertEq(computed, HATS_VOTING_STRATEGY, "Computed CREATE2 address must match expected strategy");
    }

    function test_hatsStrategyEnabled() public {
        _executeGovernanceProposal();

        assertTrue(
            IAzoriusStrategy(address(AZORIUS)).isStrategyEnabled(HATS_VOTING_STRATEGY),
            "Hats voting strategy should be enabled on Azorius"
        );
    }

    function test_decentHatsModuleDisabled() public {
        _executeGovernanceProposal();

        assertFalse(
            ISafe(SHUTTER_SAFE).isModuleEnabled(DECENT_HATS),
            "DecentHatsModificationModule should be disabled after proposal"
        );
    }

    function test_oldStrategyDisabled() public {
        _executeGovernanceProposal();

        assertFalse(
            IAzoriusStrategy(address(AZORIUS)).isStrategyEnabled(address(LINEAR_ERC20_VOTING)),
            "Old LinearERC20Voting strategy should be disabled after proposal"
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

        _submitPassAndExecuteProposal(_proposerHatWearers()[0], HATS_VOTING_STRATEGY, txs);

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
            IAzoriusStrategy(HATS_VOTING_STRATEGY).isProposer(nobody),
            "Address without hat should NOT propose via hats strategy"
        );

        vm.mockCall(
            HATS_PROTOCOL,
            abi.encodeWithSignature("isWearerOfHat(address,uint256)", nobody, PROPOSER_HAT_ID),
            abi.encode(true)
        );

        assertTrue(
            IAzoriusStrategy(HATS_VOTING_STRATEGY).isProposer(nobody),
            "Hat wearer should be able to propose via hats strategy"
        );
        assertFalse(
            IAzoriusStrategy(address(LINEAR_ERC20_VOTING)).isProposer(nobody),
            "Hat should NOT grant proposal rights on old strategy"
        );
    }
}
