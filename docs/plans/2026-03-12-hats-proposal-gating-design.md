# Hats Proposal Gating Design

## Goal

Add an executable script that submits the hats proposal-gating governance proposal onchain while guaranteeing that the script and fork tests use the exact same transaction-building logic.

## Chosen Approach

Extract the hats proposal-gating transaction builders from `test/fork/HatsProposalGating.t.sol` into one reusable Solidity helper under `src/`. The helper will own:

- the constants used by the proposal,
- the `createRoleHats` calldata builder,
- the hats voting strategy initializer builder,
- the base 5-transaction proposal,
- the full 6-transaction proposal that also maxes out the old strategy's proposer weight.

The existing fork test will call the shared helper instead of building transactions inline. A new script will read a JSON array of wearer addresses from an environment variable, build the same proposal through the helper, and submit it through `Azorius.submitProposal(...)`.

## Why This Is Simplest

- There is only one source of truth for the proposal transactions.
- The fork test continues proving the same live governance flow without duplicated encoding logic.
- The script stays thin: parse env, call helper, broadcast `submitProposal`.
- Address-array support is native in the helper, so future wearer additions do not require code changes.

## Data Flow

1. Script reads `DEPLOYER_PRIVATE_KEY`.
2. Script reads `PROPOSER_HAT_WEARERS` as a JSON array string.
3. Script wraps that string in a tiny JSON object and parses it into `address[]`.
4. Script calls the shared helper to build `IAzorius.Transaction[]`.
5. Script broadcasts `AZORIUS.submitProposal(...)` using the current proposer strategy.

## Testing Strategy

- First add/adjust tests so the shared helper is the path under test.
- Keep the existing fork tests as the high-confidence execution proof.
- Add a focused test for the script-side wearer parsing helper so JSON array env input is covered.

## Error Handling

- Revert if the wearer array env var is empty or parses to zero addresses.
- Keep metadata and transaction ordering explicit so proposal submission is deterministic.

## Files Expected

- Create `src/proposals/HatsProposalGatingProposal.sol`
- Create `script/SubmitHatsProposalGating.s.sol`
- Modify `test/fork/HatsProposalGating.t.sol`
- Add a focused test for the script parsing path if needed
