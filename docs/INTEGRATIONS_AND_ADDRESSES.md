# Integration Contracts and Addresses

This document is the canonical reference for:

- which contracts/accounts `SecurityCouncilAzorius` depends on
- how those dependencies are used
- where to record production addresses per network

## Current known values (as of 2026-02-12)

No production contract addresses are committed in this repository yet.

- `.env.example` contains placeholders
- no `.env` with deployment values is present in this workspace
- Safe contract version is not inferable until `SAFE_ADDRESS` is provided on a target chain

## Actual contracts expected in production

| Layer | Contract type | Expected identifier |
| --- | --- | --- |
| Guard | `SecurityCouncilAzorius` | deployed from `src/SecurityCouncilAzorius.sol` |
| Governance module | `Azorius` | configured via `AZORIUS_ADDRESS` |
| Safe proxy | `SafeProxy` / `GnosisSafeProxy` | configured via `SAFE_ADDRESS` |
| Safe singleton | `Safe` implementation behind proxy | resolved from `SAFE_ADDRESS` via `masterCopy()` |

## Interacted contracts and accounts

| Component | Address source | Role in system | Interaction points |
| --- | --- | --- | --- |
| `SecurityCouncilAzorius` (this contract) | Deployment output | Safe guard that enforces vetoes | Implements `IGuard.checkTransaction` and council veto controls |
| Azorius module | Constructor arg `_azorius` (`AZORIUS_ADDRESS`) | Canonical source of proposal tx hashes and tx hash computation | `getProposal` in `vetoProposal`/`unvetoProposal`, `getTxHash` in `checkTransaction` |
| Safe (guard host) | Safe config (not constructor input) | Calls guard hooks during module execution | Calls `checkTransaction` before execution and `checkAfterExecution` after execution |
| Council account (EOA or multisig) | Constructor arg `_council` (`COUNCIL_ADDRESS`) | Exclusive authority for veto controls | Caller for `vetoProposal`, `unvetoProposal`, `vetoTx`, `unvetoTx`, `multicall` |
| Proposal target contracts | Proposal payload data in Azorius | Business logic executed by Safe when tx is allowed | Not called directly by guard; included in hash preimage passed to Azorius |

## Address registry (fill per deployment)

Do not rely on memory or chat history for addresses. Record every deployment here and keep it updated in PRs.

| Network | Chain ID | Safe proxy address | Safe singleton address | Safe version | Azorius address | Council address | SecurityCouncilAzorius address | Deployment tx | Deployed at (UTC) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mainnet | `1` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| Sepolia | `11155111` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |

## Deployment input vs operational addresses

Deployment script inputs (`script/DeploySecurityCouncilAzorius.s.sol`):

- required: `COUNCIL_ADDRESS`
- required: `AZORIUS_ADDRESS`

Operational addresses (not constructor inputs, but required for runbooks and incident response):

- Safe address where guard is installed
- Safe singleton (mastercopy) address
- Safe contract version
- deployed guard address
- previous guard address (after rotations)

## How to resolve Safe singleton and version

Once `SAFE_ADDRESS` and `RPC_URL` are set:

```bash
cast call "$SAFE_ADDRESS" "masterCopy()(address)" --rpc-url "$RPC_URL"
cast call "$SAFE_ADDRESS" "VERSION()(string)" --rpc-url "$RPC_URL"
```

Record both outputs in the address registry table.

## Verification checklist for addresses

Before deployment:

1. Confirm `COUNCIL_ADDRESS` is the approved council signer/multisig.
2. Confirm `AZORIUS_ADDRESS` is the correct module for the target Safe.
3. Confirm Safe address and chain ID match the intended environment.

After deployment:

1. Record deployed guard address and deployment tx hash in the table above.
2. Resolve and record Safe singleton address and Safe version.
3. Verify source and constructor args on explorer.
4. Record guard installation tx on Safe.
5. For rotations, append new row and retain old guard address for auditability.
