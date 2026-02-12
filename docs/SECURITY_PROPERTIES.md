# Security Properties

This document defines the expected behavior of `SecurityCouncilAzorius`.

## Core Guarantees

1. Access Control:
   - Only `council` can call `vetoProposal`, `unvetoProposal`, `vetoTx`, `unvetoTx`, `multicall`.
2. Veto Enforcement:
   - If `vetoedTxHash[hash] == true`, `checkTransaction` reverts with `TransactionVetoed(hash)`.
3. Executability Restoration:
   - If a hash is unvetoed (`false`), guard checks no longer block execution for that hash.
4. Proposal-to-Hash Expansion:
   - `vetoProposal` and `unvetoProposal` apply state changes to every hash returned by `Azorius.getProposal`.
5. Global Hash Scope:
   - Veto state is global per hash and may affect multiple proposals sharing the same hash.

## Event Semantics

1. `TxHashVetoed` is emitted only when a hash transitions `false -> true`.
2. `TxHashUnvetoed` is emitted only when a hash transitions `true -> false`.
3. `ProposalVetoed`/`ProposalUnvetoed` carry the number of hashes that actually changed state.

## Non-Goals

1. This contract does not track proposal lifecycle phases (timelock/execution windows).
2. This contract does not enforce caller restrictions on `checkTransaction`; integration is expected through Safe guard wiring.

## Verification Status

1. Unit tests cover access control, event semantics, and veto transitions.
2. Lifecycle tests cover guard behavior during simulated module execution.
3. Invariant tests cover persistent veto enforcement and unvetoed executability.
