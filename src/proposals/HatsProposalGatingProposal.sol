// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAzorius} from "src/interfaces/IAzorius.sol";
import {ILinearERC20Voting} from "src/interfaces/ILinearERC20Voting.sol";
import {GovernanceProposal} from "src/proposals/GovernanceProposal.sol";

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

interface ISafe {
    function enableModule(address module) external;
    function disableModule(address prevModule, address module) external;
}

interface IModuleProxyFactory {
    function deployModule(address masterCopy, bytes memory initializer, uint256 saltNonce) external returns (address);
}

/// @notice Builds the governance proposal that enables Hats-gated proposal creation
///         on Shutter DAO. Creates proposer role hats, deploys a new voting strategy
///         with hat-based access control, and maxes out the old strategy's proposer
///         weight to effectively gate it.
library HatsProposalGatingProposal {
    function DECENT_HATS() internal pure returns (address) {
        return 0x9755dD7E27E90b4fC00E50EC14DD2D08a79064d3;
    }

    function MODULE_PROXY_FACTORY() internal pure returns (address) {
        return 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    }

    function HATS_VOTING_IMPL() internal pure returns (address) {
        return 0x065bDFeE6d7b70b00bbF629aF76362fcDc693e04;
    }

    function HATS_PROTOCOL() internal pure returns (address) {
        return 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
    }

    function HATS_VOTING_STRATEGY() internal pure returns (address) {
        return 0x7FF645b803FF3Bc890e3568B503BC1F37d32Edd1;
    }

    function TOP_HAT_ID() internal pure returns (uint256) {
        return 0x0000004000000000000000000000000000000000000000000000000000000000;
    }

    function ADMIN_HAT_ID() internal pure returns (uint256) {
        return 0x0000004000010000000000000000000000000000000000000000000000000000;
    }

    function PROPOSER_HAT_ID() internal pure returns (uint256) {
        return 0x0000004000010002000000000000000000000000000000000000000000000000;
    }

    function ERC6551_REGISTRY() internal pure returns (address) {
        return 0x000000006551c19487814612e58FE06813775758;
    }

    function HATS_ACCOUNT_IMPL() internal pure returns (address) {
        return 0xfEf83A660b7C10a3EdaFdCF62DEee1fD8a875D29;
    }

    function TOP_HAT_ACCOUNT() internal pure returns (address) {
        return 0xC30Ed08466e2A713D6567DAB84468ecE6A455f1b;
    }

    function KEY_VALUE_PAIRS() internal pure returns (address) {
        return 0x535B64f9Ef529Ac8B34Ac7273033bBE67B34f131;
    }

    function HATS_MODULE_FACTORY() internal pure returns (address) {
        return 0x0a3f85fa597B6a967271286aA0724811acDF5CD9;
    }

    function HATS_ELECTIONS_IMPL() internal pure returns (address) {
        return 0xd3b916a8F0C4f9D1d5B6Af29c3C012dbd4f3149E;
    }

    function DEPLOYMENT_SALT() internal pure returns (uint256) {
        return 0xb3b402edfcc21f484f1f5018c55461995d61d0f5ca5b5fada2e0354e33001c07;
    }

    function LIGHT_ACCOUNT_FACTORY() internal pure returns (address) {
        return 0x0000000000400CdFef5E2714E63d8040b700BC24;
    }

    function metadata() internal pure returns (string memory) {
        return '{"title":"Hats Protocol Proposal Gating","description":"Enable hat-gated proposal creation for Shutter DAO governance"}';
    }

    function buildProposal(address[] memory wearers)
        internal
        pure
        returns (address strategy, IAzorius.Transaction[] memory txs, string memory _metadata)
    {
        strategy = GovernanceProposal.LINEAR_ERC20_VOTING();
        txs = buildProposalTransactions(wearers);
        _metadata = metadata();
    }

    function buildProposalTransactions(address[] memory wearers)
        internal
        pure
        returns (IAzorius.Transaction[] memory txs)
    {
        IAzorius.Transaction[] memory baseTxs = buildBaseTransactions(wearers);

        txs = new IAzorius.Transaction[](baseTxs.length + 1);
        for (uint256 i = 0; i < baseTxs.length; i++) {
            txs[i] = baseTxs[i];
        }

        txs[baseTxs.length] = IAzorius.Transaction({
            to: GovernanceProposal.LINEAR_ERC20_VOTING(),
            value: 0,
            data: abi.encodeCall(ILinearERC20Voting.updateRequiredProposerWeight, (1_000_000_000e18)),
            operation: IAzorius.Operation.Call
        });
    }

    function buildBaseTransactions(address[] memory wearers) internal pure returns (IAzorius.Transaction[] memory txs) {
        txs = new IAzorius.Transaction[](5);

        txs[0] = IAzorius.Transaction({
            to: GovernanceProposal.SHUTTER_SAFE(),
            value: 0,
            data: abi.encodeCall(ISafe.enableModule, (DECENT_HATS())),
            operation: IAzorius.Operation.Call
        });

        txs[1] = IAzorius.Transaction({
            to: DECENT_HATS(), value: 0, data: buildCreateRoleHatCalldata(wearers), operation: IAzorius.Operation.Call
        });

        txs[2] = IAzorius.Transaction({
            to: GovernanceProposal.SHUTTER_SAFE(),
            value: 0,
            data: abi.encodeCall(ISafe.disableModule, (address(0x1), DECENT_HATS())),
            operation: IAzorius.Operation.Call
        });

        txs[3] = IAzorius.Transaction({
            to: MODULE_PROXY_FACTORY(),
            value: 0,
            data: abi.encodeCall(
                IModuleProxyFactory.deployModule, (HATS_VOTING_IMPL(), buildStrategyInitializer(), DEPLOYMENT_SALT())
            ),
            operation: IAzorius.Operation.Call
        });

        txs[4] = IAzorius.Transaction({
            to: GovernanceProposal.AZORIUS(),
            value: 0,
            data: abi.encodeCall(IAzorius.enableStrategy, (HATS_VOTING_STRATEGY())),
            operation: IAzorius.Operation.Call
        });
    }

    function buildCreateRoleHatCalldata(address[] memory wearers) internal pure returns (bytes memory) {
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
            hatsProtocol: HATS_PROTOCOL(),
            erc6551Registry: ERC6551_REGISTRY(),
            hatsAccountImplementation: HATS_ACCOUNT_IMPL(),
            topHatId: TOP_HAT_ID(),
            topHatAccount: TOP_HAT_ACCOUNT(),
            keyValuePairs: KEY_VALUE_PAIRS(),
            hatsModuleFactory: HATS_MODULE_FACTORY(),
            hatsElectionsEligibilityImplementation: HATS_ELECTIONS_IMPL(),
            adminHatId: ADMIN_HAT_ID(),
            hats: hats
        });

        return abi.encodeCall(IDecentHatsModificationModule.createRoleHats, (params));
    }

    function buildStrategyInitializer() internal pure returns (bytes memory) {
        uint256[] memory whitelistedHats = new uint256[](1);
        whitelistedHats[0] = PROPOSER_HAT_ID();

        bytes memory initParams = abi.encode(
            GovernanceProposal.SHUTTER_SAFE(),
            GovernanceProposal.SHUTTER_TOKEN(),
            GovernanceProposal.AZORIUS(),
            uint32(21_600),
            uint256(30_000),
            uint256(500_000),
            HATS_PROTOCOL(),
            whitelistedHats,
            LIGHT_ACCOUNT_FACTORY()
        );

        return abi.encodeWithSelector(bytes4(keccak256("setUp(bytes)")), initParams);
    }
}
