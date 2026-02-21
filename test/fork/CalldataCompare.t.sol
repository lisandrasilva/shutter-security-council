// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IAzoriusFork} from "./ShutterGovernance.base.t.sol";
import {
    HatsProposalGatingTest,
    CreateRoleHatsParams,
    HatParams,
    SablierStreamParams,
    Timestamps,
    Broker
} from "./HatsProposalGating.t.sol";

/**
 * @notice Reads original calldata from file, builds our version, compares byte-by-byte.
 */
contract CalldataCompareTest is Test {
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
    address constant HATTED_USER = 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041;
    address constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    address constant VOTING_IMPL = 0x065bDFeE6d7b70b00bbF629aF76362fcDc693e04;
    address constant EXPECTED_NEW_STRATEGY = 0x7FF645b803FF3Bc890e3568B503BC1F37d32Edd1;
    address constant LIGHT_ACCOUNT_FACTORY = 0x0000000000400CdFef5E2714E63d8040b700BC24;

    uint256 constant TOP_HAT_ID = 0x0000004000000000000000000000000000000000000000000000000000000000;
    uint256 constant ADMIN_HAT_ID = 0x0000004000010000000000000000000000000000000000000000000000000000;
    uint256 constant PROPOSER_HAT_ID = 0x0000004000010002000000000000000000000000000000000000000000000000;
    uint256 constant DEPLOYMENT_SALT = 0xb3b402edfcc21f484f1f5018c55461995d61d0f5ca5b5fada2e0354e33001c07;

    function test_fullCalldataComparison() public {
        // 1. Read original calldata from file
        string memory rawHex = vm.readFile("test/fork/original_calldata.txt");
        bytes memory original = vm.parseBytes(rawHex);

        // 2. Build our version of the full submitProposal calldata
        IAzoriusFork.Transaction[] memory txs = _prepareTransactions();

        bytes memory generated = abi.encodeWithSelector(
            IAzoriusFork.submitProposal.selector,
            LINEAR_ERC20_VOTING, // strategy
            bytes(""), // metadata bytes (empty)
            txs, // transactions
            '{"title":"test","description":"test (hoping this comes to my wallet for me to cancel first lol)"}'
        );

        emit log_named_uint("Original length", original.length);
        emit log_named_uint("Generated length", generated.length);

        // 3. Compare byte-by-byte
        if (original.length != generated.length) {
            emit log("LENGTH MISMATCH");
        }

        uint256 minLen = original.length < generated.length ? original.length : generated.length;
        uint256 mismatches = 0;
        uint256 firstMismatch = type(uint256).max;

        for (uint256 i = 0; i < minLen; i++) {
            if (original[i] != generated[i]) {
                if (mismatches < 5) {
                    emit log_named_uint("Mismatch at byte", i);
                    emit log_named_uint("  word index", i / 32);
                    emit log_named_bytes32("  original word", _wordAt(original, (i / 32) * 32));
                    emit log_named_bytes32("  generated word", _wordAt(generated, (i / 32) * 32));
                }
                if (firstMismatch == type(uint256).max) firstMismatch = i;
                mismatches++;
            }
        }

        if (mismatches == 0 && original.length == generated.length) {
            emit log("FULL CALLDATA MATCH!");
        } else {
            emit log_named_uint("Total mismatched bytes", mismatches);
            emit log_named_uint("First mismatch at byte", firstMismatch);
        }

        assertEq(keccak256(original), keccak256(generated), "Full calldata mismatch");
    }

    // ── Build transactions (same as HatsProposalGatingTest) ─────────

    function _prepareTransactions() internal pure returns (IAzoriusFork.Transaction[] memory txs) {
        txs = new IAzoriusFork.Transaction[](5);

        // TX0: enableModule
        txs[0] = IAzoriusFork.Transaction({
            to: SHUTTER_SAFE,
            value: 0,
            data: abi.encodeWithSignature("enableModule(address)", DECENT_HATS),
            operation: IAzoriusFork.Operation.Call
        });

        // TX1: createRoleHats (DelegateCall)
        txs[1] = IAzoriusFork.Transaction({
            to: DECENT_HATS, value: 0, data: _buildCreateRoleHatsData(), operation: IAzoriusFork.Operation.DelegateCall
        });

        // TX2: disableModule
        txs[2] = IAzoriusFork.Transaction({
            to: SHUTTER_SAFE,
            value: 0,
            data: abi.encodeWithSignature("disableModule(address,address)", address(0x1), DECENT_HATS),
            operation: IAzoriusFork.Operation.Call
        });

        // TX3: deployModule
        txs[3] = IAzoriusFork.Transaction({
            to: MODULE_PROXY_FACTORY,
            value: 0,
            data: abi.encodeWithSignature(
                "deployModule(address,bytes,uint256)", VOTING_IMPL, _buildSetUpInitializer(), DEPLOYMENT_SALT
            ),
            operation: IAzoriusFork.Operation.Call
        });

        // TX4: enableStrategy
        txs[4] = IAzoriusFork.Transaction({
            to: address(AZORIUS),
            value: 0,
            data: abi.encodeWithSignature("enableStrategy(address)", EXPECTED_NEW_STRATEGY),
            operation: IAzoriusFork.Operation.Call
        });
    }

    function _buildCreateRoleHatsData() internal pure returns (bytes memory) {
        HatParams[] memory hats = new HatParams[](1);
        SablierStreamParams[] memory emptyStreams = new SablierStreamParams[](0);
        hats[0] = HatParams({
            wearer: HATTED_USER,
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
            address(0xe485E2f1bab389C08721B291f6b59780feC83Fd7), // token
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

    function _wordAt(bytes memory data, uint256 offset) internal pure returns (bytes32 result) {
        if (offset + 32 > data.length) return bytes32(0);
        assembly { result := mload(add(add(data, 32), offset)) }
    }
}
