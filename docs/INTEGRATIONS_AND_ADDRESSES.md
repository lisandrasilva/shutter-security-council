# Integration Contracts and Addresses

This document is the canonical reference for:

- which contracts/accounts `SecurityCouncilAzorius` depends on
- how those dependencies are used
- where to record production addresses per network

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

| Network | Chain ID | Safe address | Azorius address | Council address | SecurityCouncilAzorius address | Deployment tx | Deployed at (UTC) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Mainnet | `1` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |
| Sepolia | `11155111` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |

## Deployment input vs operational addresses

Deployment script inputs (`script/DeploySecurityCouncilAzorius.s.sol`):

- required: `COUNCIL_ADDRESS`
- required: `AZORIUS_ADDRESS`

Operational addresses (not constructor inputs, but required for runbooks and incident response):

- Safe address where guard is installed
- deployed guard address
- previous guard address (after rotations)

## Verification checklist for addresses

Before deployment:

1. Confirm `COUNCIL_ADDRESS` is the approved council signer/multisig.
2. Confirm `AZORIUS_ADDRESS` is the correct module for the target Safe.
3. Confirm Safe address and chain ID match the intended environment.

After deployment:

1. Record deployed guard address and deployment tx hash in the table above.
2. Verify source and constructor args on explorer.
3. Record guard installation tx on Safe.
4. For rotations, append new row and retain old guard address for auditability.
