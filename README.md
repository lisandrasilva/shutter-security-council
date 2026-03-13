# SecurityCouncilAzorius

`SecurityCouncilAzorius` is an `IGuard`-compatible veto guard for Azorius proposal transactions.

On Safe `1.3.0`, this guard must be installed on the Azorius module (`Azorius.setGuard(...)`) to affect module execution.

This repository contains the production contract, deployment script, and verification-focused test suites for unit, lifecycle, and invariants.

## Documentation Index

| Document | Description |
| --- | --- |
| [Governance Parameters](docs/GOVERNANCE_PARAMETERS.md) | Current on-chain parameters, suggested changes, before/after timeline, and security analysis |
| [Integrations and Addresses](docs/INTEGRATIONS_AND_ADDRESSES.md) | Contract dependencies, per-network address registry, and deployment verification checklist |
| [Operations Runbook](docs/OPERATIONS.md) | Cross-proposal hash collisions, council rotation, guard placement, and deployment controls |
| [Security Properties](docs/SECURITY_PROPERTIES.md) | Core guarantees, event semantics, non-goals, and verification status |

## Why this exists

Azorius proposals contain one or more transactions. When all transactions are passed in a single `executeProposal` call (the standard path), execution is atomic. Azorius also supports partial execution across multiple calls via `executionCounter`. This guard adds a council-controlled safety layer at execution time:

- Council can veto or unveto at proposal scope (`vetoProposal`, `unvetoProposal`)
- Council can veto or unveto at transaction-hash scope (`vetoTx`, `unvetoTx`)
- Azorius module execution is blocked if `checkTransaction` resolves to a vetoed Azorius transaction hash

## Architecture and responsibilities

- Contract: `src/SecurityCouncilAzorius.sol`
- Integration points:
  - Reads proposal transaction hashes from Azorius (`IAzorius.getProposal`)
  - Computes execution hash through Azorius (`IAzorius.getTxHash`)
  - Enforces gate through `IGuard.checkTransaction` when configured as the Azorius module guard
- Authority model:
  - `council` is immutable
  - `azorius` is immutable
  - only `council` can mutate veto state

Detailed integration and address registry:

- `docs/INTEGRATIONS_AND_ADDRESSES.md`
  - includes Safe proxy address, Safe singleton address, and Safe contract version tracking per network
  - includes current mainnet values for Safe and Azorius plus proposal-fork testing companion contracts

## Functional behavior

### 1. Veto storage model

Veto state is stored as:

```solidity
mapping(bytes32 => bool) public vetoedTxHash;
```

Key implication: state is global by `txHash`, not scoped by `proposalId`.

If two proposals include the same tx hash, vetoing either one blocks both execution paths until unvetoed.

### 2. Council operations

- `vetoProposal(uint32 proposalId)`
  - Loads all tx hashes from Azorius for the proposal
  - Marks each non-vetoed hash as vetoed
  - Emits per-hash and aggregate events
- `unvetoProposal(uint32 proposalId)`
  - Clears veto for each currently vetoed hash in that proposal
  - Emits per-hash and aggregate events
- `vetoTx(bytes32 txHash)` and `unvetoTx(bytes32 txHash)`
  - Fine-grained emergency controls for a single hash
- `multicall(bytes[] calldata calls)`
  - Allows council to batch internal operations atomically
  - Bubbles original revert data if any subcall fails

### 3. Execution gate

- `checkTransaction(...)` computes the Azorius tx hash for the pending execution
- Reverts with `TransactionVetoed(txHash)` when hash is vetoed
- `checkAfterExecution(...)` is intentionally a no-op

### 4. Guard placement requirement (Safe 1.3.0)

- Safe `1.3.0` does not run Safe transaction guards for module execution (`execTransactionFromModule`).
- Azorius proposal execution uses the module path.
- Therefore veto enforcement requires setting this contract as Azorius guard (`Azorius.setGuard(address(guard))`).

### 5. Visibility and standards

- `isProposalVetoed(uint32 proposalId)` returns true only when all proposal hashes are currently vetoed
- `supportsInterface` returns support for:
  - `IGuard`
  - `IERC165`

## Lifecycle of operations

### Phase A: Deployment and activation

1. Deploy guard with immutable `council` and `azorius` addresses.
2. Install guard on Azorius module (`setGuard`) for module-path enforcement.
3. Verify configuration and run post-activation smoke checks.

### Phase B: Normal governance execution path

1. Azorius proposal exists with one or more tx hashes.
2. A module execution attempts to run one transaction through Safe.
3. Azorius module invokes `checkTransaction` on its configured guard.
4. Guard asks Azorius to compute tx hash from execution params.
5. If hash is not vetoed, execution continues.

### Phase C: Incident response (veto path)

1. Council identifies risky transaction/proposal.
2. Council calls `vetoTx` or `vetoProposal`.
3. Any matching future execution attempt reverts at guard check.
4. Council coordinates remediation and governance comms.

### Phase D: Recovery (unveto path)

1. Risk is resolved or governance intent is restored.
2. Council calls `unvetoTx` or `unvetoProposal`.
3. Matching execution paths become available again.

### Phase E: Council rotation

`council` is immutable. Rotation requires deploying a new guard and replacing guard wiring on Safe.

Operational details: `docs/OPERATIONS.md`

## Security properties and non-goals

Canonical properties and expectations are documented in:

- `docs/SECURITY_PROPERTIES.md`

Important non-goals:

- This guard does not manage Azorius timelock/execution windows.
- This guard does not maintain proposal lifecycle state.
- This guard is an execution-time veto layer only.

## Repository layout

- `src/SecurityCouncilAzorius.sol` core guard contract
- `script/DeploySecurityCouncilAzorius.s.sol` deployment entrypoint
- `test/unit/` function-level and event semantics tests
- `test/lifecycle/` governance flow and module execution behavior
- `test/invariant/` state and execution invariants under randomized action sequences
- `test/fork/` fork-oriented governance scaffolding and address/version assertions
- `docs/` security properties and operational runbooks
  - `docs/INTEGRATIONS_AND_ADDRESSES.md` interacted contracts and per-network address registry

## Testing and verification

Run complete suite:

```bash
forge test -vvv
```

Run only unit tests:

```bash
forge test --match-path "test/unit/*" -vvv
```

Run only lifecycle tests:

```bash
forge test --match-path "test/lifecycle/*" -vvv
```

Run only invariant tests:

```bash
forge test --match-path "test/invariant/*" -vvv
```

## Deployment

1. Copy `.env.example` to `.env`.
2. Set required variables.
3. Run deployment script.

```bash
source .env
forge script script/DeploySecurityCouncilAzorius.s.sol:DeploySecurityCouncilAzorius \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --verify \
  -vvvv
```

Required environment variables:

- `RPC_URL`
- `DEPLOYER_PRIVATE_KEY`
- `COUNCIL_ADDRESS`
- `AZORIUS_ADDRESS`
- `ETHERSCAN_API_KEY` (when using `--verify`)

## Pre-mainnet release checklist

- Run unit, lifecycle, fuzz, and invariant suites with no skips.
- Review constructor args from approved source of truth.
- Dry-run deploy and guard wiring on a fork of target chain.
- Verify source and constructor args on explorer.
- Verify `Azorius.guard()` equals deployed `SecurityCouncilAzorius` address.
- Rehearse veto and unveto procedures with operators.
- Validate council rotation runbook before first production deployment.
