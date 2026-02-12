// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";

interface ISafeProxyLike {
    function masterCopy() external view returns (address);
}

interface ISafeVersion {
    function VERSION() external view returns (string memory);
}

contract ShutterGovernanceAddressesForkTest is Test {
    address internal constant SHUTTER_SAFE = 0x36bD3044ab68f600f6d3e081056F34f2a58432c4;
    address internal constant SHUTTER_SAFE_SINGLETON = 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552;
    address internal constant SHUTTER_AZORIUS = 0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e;

    function test_mainnetAddressesAndSafeVersion() external {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            rpcUrl = vm.envOr("RPC_URL", string(""));
        }
        if (bytes(rpcUrl).length == 0) {
            emit log("Skipping: set MAINNET_RPC_URL (or RPC_URL) to run fork assertions.");
            return;
        }

        vm.createSelectFork(rpcUrl);
        assertEq(block.chainid, 1, "Fork is not Ethereum mainnet");

        assertGt(SHUTTER_SAFE.code.length, 0, "Safe has no code");
        assertGt(SHUTTER_AZORIUS.code.length, 0, "Azorius has no code");

        address singleton = ISafeProxyLike(SHUTTER_SAFE).masterCopy();
        assertEq(singleton, SHUTTER_SAFE_SINGLETON, "Unexpected Safe singleton");

        string memory version = ISafeVersion(SHUTTER_SAFE).VERSION();
        assertEq(version, "1.3.0", "Unexpected Safe version");
    }
}
