#!/usr/bin/env python3

import sys
from eth_abi import decode

# Read the calldata from file
with open('calldata.txt', 'r') as f:
    calldata = f.read().strip()

# Remove the function selector (first 4 bytes = 8 hex chars)
calldata_without_selector = calldata[10:]

# Convert hex string to bytes
calldata_bytes = bytes.fromhex(calldata_without_selector)

# Define the ABI types for submitProposal parameters
types = [
    'address',  # strategy
    'bytes',    # metadataData  
    '(address,uint256,bytes,uint8)[]',  # transactions array
    'string'    # metadata
]

# Decode the calldata
try:
    decoded = decode(types, calldata_bytes)
    strategy, metadataData, transactions, metadata = decoded
    
    print(f"Strategy: {strategy}")
    print(f"MetadataData: {metadataData.hex()}")
    print(f"Number of transactions: {len(transactions)}")
    print(f"Metadata: {metadata}")
    print()
    
    for i, tx in enumerate(transactions):
        to, value, data, operation = tx
        print(f"Transaction {i}:")
        print(f"  To: {to}")
        print(f"  Value: {value}")
        print(f"  Data: 0x{data.hex()}")
        print(f"  Operation: {operation}")
        print()

except Exception as e:
    print(f"Error decoding: {e}")
    sys.exit(1)