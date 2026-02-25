// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IAzoriusFork} from "./ShutterGovernance.base.t.sol";
import {CreateRoleHatsParams, HatParams, SablierStreamParams, Timestamps, Broker} from "./HatsProposalGating.t.sol";

contract CalldataEmitTest is Test {
    // ── Shared constants ──────────────────────────────────────────────────
    address constant SHUTTER_SAFE = 0x36bD3044ab68f600f6d3e081056F34f2a58432c4;
    address constant DECENT_HATS = 0x9755dD7E27E90b4fC00E50EC14DD2D08a79064d3;
    IAzoriusFork constant AZORIUS = IAzoriusFork(0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e);
    address constant LINEAR_ERC20_VOTING = 0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F;

    address constant HATS_CONTRACT = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
    address constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address constant HATS_ACCOUNT_IMPL = 0xfEf83A660b7C10a3EdaFdCF62DEee1fD8a875D29;
    address constant TOP_HAT_ACCOUNT = 0xC30Ed08466e2A713D6567DAB84468ecE6A455f1b;
    address constant KEY_VALUE_PAIRS = 0x535B64f9Ef529Ac8B34Ac7273033bBE67B34f131;
    address constant HATS_MODULE_FACTORY = 0x0a3f85fa597B6a967271286aA0724811acDF5CD9;
    address constant HATS_ELECTIONS_IMPL = 0xd3b916a8F0C4f9D1d5B6Af29c3C012dbd4f3149E;
    address constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    address constant VOTING_IMPL = 0x065bDFeE6d7b70b00bbF629aF76362fcDc693e04;
    address constant EXPECTED_NEW_STRATEGY = 0x7FF645b803FF3Bc890e3568B503BC1F37d32Edd1;
    address constant LIGHT_ACCOUNT_FACTORY = 0x0000000000400CdFef5E2714E63d8040b700BC24;

    uint256 constant TOP_HAT_ID = 0x0000004000000000000000000000000000000000000000000000000000000000;
    uint256 constant ADMIN_HAT_ID = 0x0000004000010000000000000000000000000000000000000000000000000000;
    uint256 constant PROPOSER_HAT_ID = 0x0000004000010002000000000000000000000000000000000000000000000000;
    uint256 constant DEPLOYMENT_SALT = 0xb3b402edfcc21f484f1f5018c55461995d61d0f5ca5b5fada2e0354e33001c07;

    // ── Per-variant hat wearer ────────────────────────────────────────────
    address constant ORIGINAL_HATTED_USER = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
    address constant NEW_HATTED_USER = 0x76A6D08b82034b397E7e09dAe4377C18F132BbB8;

    // ── Emit helpers ──────────────────────────────────────────────────────

    function test_emitTx1() public {
        bytes memory gen = _buildCreateRoleHatsData(ORIGINAL_HATTED_USER);
        emit log_named_bytes("GENERATED_TX1", gen);
    }

    function test_emitTx3Initializer() public {
        bytes memory gen = _buildSetUpInitializer();
        emit log_named_bytes("GENERATED_INITIALIZER", gen);
    }

    function test_emitFullCalldata_original() public {
        bytes memory calldata_ = _buildFullSubmitProposalCalldata(ORIGINAL_HATTED_USER);
        emit log_named_bytes("FULL_CALLDATA_ORIGINAL", calldata_);
    }

    function test_emitFullCalldata_newHattedUser() public {
        bytes memory calldata_ = _buildFullSubmitProposalCalldata(NEW_HATTED_USER);
        emit log_named_bytes("FULL_CALLDATA_NEW", calldata_);
    }

    // ── Build full submitProposal calldata ─────────────────────────────────

    function _buildFullSubmitProposalCalldata(address hattedUser) internal pure returns (bytes memory) {
        IAzoriusFork.Transaction[] memory txs = _prepareTransactions(hattedUser);
        return abi.encodeWithSelector(
            IAzoriusFork.submitProposal.selector,
            LINEAR_ERC20_VOTING,
            bytes(""),
            txs,
            '{"title":"test","description":"test (hoping this comes to my wallet for me to cancel first lol)"}'
        );
    }

    // ── Build transactions ────────────────────────────────────────────────

    function _prepareTransactions(address hattedUser)
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
            data: _buildCreateRoleHatsData(hattedUser),
            operation: IAzoriusFork.Operation.DelegateCall
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
                "deployModule(address,bytes,uint256)", VOTING_IMPL, _buildSetUpInitializer(), DEPLOYMENT_SALT
            ),
            operation: IAzoriusFork.Operation.Call
        });

        txs[4] = IAzoriusFork.Transaction({
            to: address(AZORIUS),
            value: 0,
            data: abi.encodeWithSignature("enableStrategy(address)", EXPECTED_NEW_STRATEGY),
            operation: IAzoriusFork.Operation.Call
        });
    }

    function _buildCreateRoleHatsData(address hattedUser) internal pure returns (bytes memory) {
        HatParams[] memory hats = new HatParams[](1);
        SablierStreamParams[] memory emptyStreams = new SablierStreamParams[](0);
        hats[0] = HatParams({
            wearer: hattedUser,
            details: "ipfs://QmXN9tFHPL6VjqrpTZ6cEnXz1ULpeiwTPVUZ1oTdZJK51s",
            imageURI: "",
            sablierStreamsParams: emptyStreams,
            termEndDateTs: 0,
            maxSupply: 1,
            isMutable: true
        });
        CreateRoleHatsParams memory params = CreateRoleHatsParams({
            hatsProtocol: HATS_CONTRACT,
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
        return abi.encodeWithSelector(bytes4(0x0ad5e427), params);
    }

    function _buildSetUpInitializer() internal pure returns (bytes memory) {
        uint256[] memory whitelistedHats = new uint256[](1);
        whitelistedHats[0] = PROPOSER_HAT_ID;
        bytes memory initParams = abi.encode(
            SHUTTER_SAFE,
            address(0xe485E2f1bab389C08721B291f6b59780feC83Fd7),
            address(AZORIUS),
            uint32(21600),
            uint256(30000),
            uint256(500000),
            HATS_CONTRACT,
            whitelistedHats,
            LIGHT_ACCOUNT_FACTORY
        );
        return abi.encodeWithSelector(bytes4(keccak256("setUp(bytes)")), initParams);
    }
}
