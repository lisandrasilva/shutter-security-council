# Hats Proposal Gating Test

## Overview
Complete Foundry fork test for the Shutter DAO governance proposal that enables Hats-gated proposal creation.

## Test File
`test/fork/HatsProposalGating.t.sol`

## What It Tests
The test validates a 6-transaction governance proposal:

1. **TX0**: `Safe.enableModule(DecentHatsModificationModule)`
2. **TX1**: `DecentHatsModificationModule.createRoleHats()` via Call
3. **TX2**: `Safe.disableModule(SENTINEL, DecentHatsModificationModule)`
4. **TX3**: `ModuleProxyFactory.deployModule()` - deploys LinearERC20VotingWithHatsProposalCreation
5. **TX4**: `Azorius.enableStrategy(newStrategy)` - enables the newly deployed strategy
6. **TX5**: `LinearERC20Voting.updateRequiredProposerWeight(1_000_000_000e18)` - sets proposer weight to total supply on old strategy

## Key Validation: CREATE2 Address Computation
The test includes **critical validation** by computing the expected proxy address using CREATE2:

- **Factory**: `0x000000000000aDdB49795b0f9bA5BC298cDda236`
- **Implementation**: `0x065bDFeE6d7b70b00bbF629aF76362fcDc693e04`
- **Salt**: `0xb3b402edfcc21f484f1f5018c55461995d61d0f5ca5b5fada2e0354e33001c07`
- **Expected Address**: `0x7FF645b803FF3Bc890e3568B503BC1F37d32Edd1`

## Fork Configuration
- **Block**: 24493552
- **Network**: Mainnet
- **Metadata**: `{"title":"Hats Protocol Proposal Gating","description":"Enable hat-gated proposal creation for Shutter DAO governance"}`

## Parameters

### Hat Configuration
- **Top Hat ID**: `0x0000004000000000000000000000000000000000000000000000000000000000`
- **Admin Hat ID**: `0x0000004000010000000000000000000000000000000000000000000000000000`
- **Proposer Hat ID**: `0x0000004000010002000000000000000000000000000000000000000000000000`

### Voting Module Setup Parameters
- **Owner**: `0x36bD3044ab68f600f6d3e081056F34f2a58432c4` (Shutter Safe)
- **Governance Token**: `0xe485E2f1bab389C08721B291f6b59780feC83Fd7` (Shutter Token)
- **Voting Period**: 21600 blocks

## Test Functions

1. **`test_proposalExecutes()`** - Submits, votes on, and executes the full proposal
2. **`test_create2AddressMatchesPrediction()`** - Validates CREATE2 computation matches expected strategy address
3. **`test_hatsStrategyEnabled()`** - Validates the new strategy is enabled in Azorius
4. **`test_decentHatsModuleDisabled()`** - Confirms DecentHatsModificationModule is disabled from Safe
5. **`test_oldStrategyProposerWeightMaxed()`** - Confirms old strategy proposer weight is set to 1B SHU (total supply)
6. **`test_hattedUserCanPropose()`** - Tests that hatted user can propose via the new strategy
7. **`test_hatEnablesProposalWithoutVotingPower()`** - Tests hat-based access vs token-based access

## Running the Tests

```bash
# Run all hats proposal gating tests
forge test --match-contract HatsProposalGatingTest -vvv

# Run specific test
forge test --match-test test_create2AddressMatchesPrediction -vvv
```

## Expected Results
When run successfully:
- All 7 test functions should pass
- CREATE2 computation should match expected strategy address
- Proposal execution should succeed without reverts
- New voting strategy should be enabled
- Old strategy proposer weight should be set to total supply (1B SHU)
- Hats-based access control should work correctly

## Troubleshooting

### RPC Issues
If you get rate limiting errors:
- Try a different RPC endpoint
- Use a premium RPC service
- Reduce test scope to individual functions

### CREATE2 Mismatch
If CREATE2 computation doesn't match:
1. The proxy factory might use different bytecode
2. Salt derivation might be different
3. Parameter encoding might be incorrect
