// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DecodeCalldata is Script {
    function run() external view {
        // Read the calldata from file
        string memory calldataFile = vm.readFile("./calldata.txt");
        bytes memory calldataBytes = vm.parseBytes(calldataFile);
        
        console.log("Calldata length:", calldataBytes.length);
        console.logBytes(calldataBytes);
        
        // Try to decode the main function call
        bytes4 selector = bytes4(calldataBytes[0:4]);
        console.log("Main selector:");
        console.logBytes4(selector);
        
        // This should be submitProposal
        if (selector == 0x0494294e) {
            console.log("This is submitProposal");
            
            // Decode the basic parameters
            (
                address strategy,
                bytes memory metadataData,
                bytes memory transactionsData,
                string memory metadata
            ) = abi.decode(calldataBytes[4:], (address, bytes, bytes, string));
            
            console.log("Strategy:", strategy);
            console.log("Metadata:", metadata);
            console.log("MetadataData length:", metadataData.length);
            console.log("TransactionsData length:", transactionsData.length);
        }
    }
}