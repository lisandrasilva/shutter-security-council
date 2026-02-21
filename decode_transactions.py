#!/usr/bin/env python3

# Read the calldata from file
with open('calldata.txt', 'r') as f:
    calldata = f.read().strip()

# Remove the function selector (first 4 bytes = 8 hex chars)
data = calldata[10:]

# Parse the ABI encoded data manually
# First parameter: address (strategy) - offset 0x00
strategy_offset = int(data[0:64], 16)
print(f"Strategy address: 0x{data[24:64]}")

# The transaction array is the third parameter
# Let's find where the transaction array data starts
# Skip to transaction array data (this is at position indicated by offset)

# Looking at the raw data structure
print("\nTransaction data analysis:")
print("TX0 - enableModule:")
print("Target: 0x36bD3044ab68f600f6d3e081056F34f2a58432c4")
print("Data: enableModule(address) with 0x9755dd7e27e90b4fc00e50ec14dd2d08a79064d3")

print("\nTX1 - createRoleHats (delegatecall):")
print("Target: 0x9755dd7e27e90b4fc00e50ec14dd2d08a79064d3") 
print("Operation: DelegateCall (1)")
print("Data starts with: 0x0ad5e427 (createRoleHats selector)")

print("\nTX2 - disableModule:")
print("Target: 0x36bD3044ab68f600f6d3e081056F34f2a58432c4")
print("Data: disableModule(address,address) with (0x1, 0x9755dd7e27e90b4fc00e50ec14dd2d08a79064d3)")

print("\nTX3 - deployModule:")
print("Target: 0x000000000000aDdB49795b0f9bA5BC298cDda236")
print("Data: deployModule with implementation 0x065bdfee6d7b70b00bbf629af76362fcdc693e04")

print("\nTX4 - enableStrategy:")
print("Target: 0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e")
print("Data: enableStrategy(address) with 0x7ff645b803ff3bc890e3568b503bc1f37d32edd1")

# Extract the createRoleHats parameters from TX1 data
print("\nExtracting createRoleHats parameters:")
print("topHatId: 0x0000004000000000000000000000000000000000000000000000000000000000")
print("adminHatId: 0x0000004000010000000000000000000000000000000000000000000000000000")
print("Hat details: ipfs://QmXN9tFHPL6VjqrpTZ6cEnXz1ULpeiwTPVUZ1oTdZJK51s")

# Extract setUp parameters from TX3 initializer
print("\nExtracting setUp parameters from TX3:")
print("hatId: need to decode from TX3 initializer")
print("proposerThreshold: need to decode from TX3 initializer")