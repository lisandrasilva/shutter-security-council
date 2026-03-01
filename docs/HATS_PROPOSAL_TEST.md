# Hats Proposal Gating Test

## Overview
Complete Foundry fork test for the Shutter DAO governance proposal that enables Hats-gated proposal creation.

## Test File
`test/fork/HatsProposalGating.t.sol`

## What It Tests
The test validates a 5-transaction governance proposal:

1. **TX0**: `Safe.enableModule(DecentHatsModificationModule)`
2. **TX1**: `DecentHatsModificationModule.createRoleHats()` via DelegateCall  
3. **TX2**: `Safe.disableModule(SENTINEL, DecentHatsModificationModule)`
4. **TX3**: `ModuleProxyFactory.deployModule()` - deploys LinearERC20VotingWithHatsProposalCreation
5. **TX4**: `Azorius.enableStrategy(newStrategy)` - enables the newly deployed strategy

## Key Validation: CREATE2 Address Computation
The test includes **critical validation** by computing the expected proxy address using CREATE2:

- **Factory**: `0x000000000000aDdB49795b0f9bA5BC298cDda236`
- **Implementation**: `0x065bDFeE6d7b70b00bbF629aF76362fcDc693e04` 
- **Salt**: `0xb3b402edfcc21f484f1f5018c55461995d61d0f5ca5b5fada2e0354e33001c07`
- **Expected Address**: `0x7FF645b803FF3Bc890e3568B503BC1F37d32Edd1`

If the computed address matches the expected address, it validates that our parameter extraction from the original calldata is exactly correct.

## Fork Configuration
- **Block**: 24493552
- **Network**: Mainnet
- **Metadata**: `{"title":"Hats Protocol Proposal Gating","description":"Enable Hats-gated proposal creation for Shutter DAO governance"}`

## Parameters Extracted from Calldata
From the original proposal calldata (`calldata.txt`), the test uses these exact values:

### Hat Configuration
- **Top Hat ID**: `0x0000004000000000000000000000000000000000000000000000000000000000`
- **Admin Hat ID**: `0x0000004000010000000000000000000000000000000000000000000000000000`  
- **Proposer Hat ID**: `0x0000004000010002000000000000000000000000000000000000000000000000`
- **Hatted User**: `0xf7253A0E87E39d2cD6365919D4a3D56D431D0041`

### Voting Module Setup Parameters  
- **Owner**: `0x36bD3044ab68f600f6d3e081056F34f2a58432c4` (Shutter Safe)
- **Governance Token**: `0xe485E2f1bab389C08721B291f6b59780feC83Fd7` (Shutter Token)
- **Voting Period**: 21600 blocks
- **Quorum**: 30000 basis points (30%)
- **Threshold**: 500000 basis points (50%)
- **Proposer Threshold**: `0x400cdfef5e2714e63d8040b700bc24`

## Test Functions

1. **`test_proposalExecution()`** - Submits, votes on, and executes the proposal
2. **`test_newStrategyEnabled()`** - Validates the new strategy is enabled in Azorius
3. **`test_moduleDisabled()`** - Confirms DecentHatsModificationModule is disabled from Safe
4. **`test_create2AddressMatches()`** - **Critical**: Validates CREATE2 computation matches expected address
5. **`test_actualDeploymentMatches()`** - Confirms deployment creates contract at expected address
6. **`test_hatGatedProposer()`** - Tests that hatted user can propose
7. **`test_nonHattedCannotPropose()`** - Tests that non-hatted user cannot propose

## Running the Tests

### Prerequisites
```bash
export PATH="$HOME/.foundry/bin:$PATH"
```

### With Mainnet RPC
```bash
# Set your RPC URL
export MAINNET_RPC_URL="https://your-mainnet-rpc-url"

# Run all tests
forge test --match-contract HatsProposalGatingTest -vvv

# Run specific test
forge test --match-test test_create2AddressMatches -vvv

# Run with specific fork block
forge test --match-contract HatsProposalGatingTest -vvv --fork-url $MAINNET_RPC_URL --fork-block-number 24493552
```

### Compilation Only (No RPC needed)
```bash
forge build
```

## Expected Results
When run successfully:
- ✅ All 6 test functions should pass
- ✅ CREATE2 computation should match expected strategy address
- ✅ Proposal execution should succeed without reverts
- ✅ New voting strategy should be enabled
- ✅ Hats-based access control should work correctly

## Troubleshooting

### RPC Issues
If you get rate limiting errors:
- Try a different RPC endpoint
- Use a premium RPC service
- Reduce test scope to individual functions

### Address Checksum Errors  
All addresses use proper EIP-55 checksumming. If you see checksum errors, the addresses have been carefully validated against the original calldata.

### CREATE2 Mismatch
If CREATE2 computation doesn't match:
1. The proxy factory might use different bytecode
2. Salt derivation might be different  
3. Parameter encoding might be incorrect

The actual deployment test (`test_actualDeploymentMatches`) provides the definitive validation.

## Implementation Notes

### Struct Definitions
The test includes complete struct definitions for:
- `CreateRoleHatsParams` - Complex nested struct for hat creation
- `HatParams` - Individual hat configuration
- `SablierStreamParams` - Token streaming (unused but required)

### Interface Extensions
- `IAzoriusExtended` - Adds `isStrategyEnabled()` view function
- `ILinearERC20VotingWithHatsProposalCreation` - New strategy interface
- `IHats` - Hat protocol interface for access checks

### Safety Features
- Proper checksum validation on all addresses
- Exact parameter matching from original calldata
- Comprehensive validation of proposal effects
- CREATE2 verification of deployment parameters