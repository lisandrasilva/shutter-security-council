// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {CreateRoleHatsParams, HatParams, SablierStreamParams, Timestamps, Broker} from "./HatsProposalGating.t.sol";

contract CalldataEmitTest is Test {
    function test_emitTx1() public {
        bytes memory gen = _buildCreateRoleHatsData();
        emit log_named_bytes("GENERATED_TX1", gen);
    }

    function test_emitTx3Initializer() public {
        bytes memory gen = _buildSetUpInitializer();
        emit log_named_bytes("GENERATED_INITIALIZER", gen);
    }

    function _buildCreateRoleHatsData() internal pure returns (bytes memory) {
        HatParams[] memory hats = new HatParams[](1);
        SablierStreamParams[] memory emptyStreams = new SablierStreamParams[](0);
        hats[0] = HatParams({
            wearer: 0xf7253A0E87E39d2cD6365919D4a3D56D431D0041,
            details: "ipfs://QmXN9tFHPL6VjqrpTZ6cEnXz1ULpeiwTPVUZ1oTdZJK51s",
            imageURI: "",
            sablierStreamsParams: emptyStreams,
            termEndDateTs: 0,
            maxSupply: 1,
            isMutable: true
        });
        CreateRoleHatsParams memory params = CreateRoleHatsParams({
            hatsProtocol: 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137,
            erc6551Registry: 0x000000006551c19487814612e58FE06813775758,
            hatsAccountImplementation: 0xfEf83A660b7C10a3EdaFdCF62DEee1fD8a875D29,
            topHatId: 0x0000004000000000000000000000000000000000000000000000000000000000,
            topHatAccount: 0xC30Ed08466e2A713D6567DAB84468ecE6A455f1b,
            keyValuePairs: 0x535B64f9Ef529Ac8B34Ac7273033bBE67B34f131,
            hatsModuleFactory: 0x0a3f85fa597B6a967271286aA0724811acDF5CD9,
            hatsElectionsEligibilityImplementation: 0xd3b916a8F0C4f9D1d5B6Af29c3C012dbd4f3149E,
            adminHatId: 0x0000004000010000000000000000000000000000000000000000000000000000,
            hats: hats
        });
        return abi.encodeWithSelector(bytes4(0x0ad5e427), params);
    }

    function _buildSetUpInitializer() internal pure returns (bytes memory) {
        uint256[] memory whitelistedHats = new uint256[](1);
        whitelistedHats[0] = 0x0000004000010002000000000000000000000000000000000000000000000000;
        bytes memory initParams = abi.encode(
            address(0x36bD3044ab68f600f6d3e081056F34f2a58432c4),
            address(0xe485E2f1bab389C08721B291f6b59780feC83Fd7),
            address(0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e),
            uint32(21600),
            uint256(30000),
            uint256(500000),
            address(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137),
            whitelistedHats,
            address(0x0000000000400CdFef5E2714E63d8040b700BC24)
        );
        return abi.encodeWithSelector(bytes4(keccak256("setUp(bytes)")), initParams);
    }
}
