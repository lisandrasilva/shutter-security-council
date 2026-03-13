# Integration Contracts and Addresses

This document is the canonical reference for:

- which contracts/accounts `SecurityCouncilAzorius` depends on
- how those dependencies are used
- where to record production addresses per network

## Current known values (as of 2026-02-12)

Known integration addresses for the target setup:

- Safe proxy: `0x36bD3044ab68f600f6d3e081056F34f2a58432c4`
- Safe singleton (resolved on-chain): `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552`
- Safe version (resolved on-chain): `1.3.0`
- Azorius: `0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e`
- Council: `0x3ea731dAF66D6A7980549f90152CD9A761B9c0C0`
- SecurityCouncilAzorius: `0xb04f553c482063a99b10c55033b56bd50b6b0334`

Governance stack addresses used in proposal-fork testing:

- LinearERC20Voting: `0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F`
- Shutter token: `0xe485E2f1bab389C08721B291f6b59780feC83Fd7`
- Default proposer used in tests: `0x9Cc9C7F874eD77df06dCd41D95a2C858cd2a2506`

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
| `SecurityCouncilAzorius` (this contract) | Deployment output | Veto guard used by Azorius module | Implements `IGuard.checkTransaction` and council veto controls |
| Azorius module | Constructor arg `_azorius` (`AZORIUS_ADDRESS`) | Canonical source of proposal tx hashes and tx hash computation; guard host for module execution | `getProposal` in `vetoProposal`/`unvetoProposal`, `getTxHash` in `checkTransaction`, `setGuard` for installation |
| Safe (avatar/target) | Safe config (not constructor input) | Module execution endpoint used by Azorius | Receives `execTransactionFromModule`; does not enforce Safe tx guard on module path in Safe `1.3.0` |
| Council account (EOA or multisig) | Constructor arg `_council` (`COUNCIL_ADDRESS`) | Exclusive authority for veto controls | Caller for `vetoProposal`, `unvetoProposal`, `vetoTx`, `unvetoTx`, `multicall` |
| Proposal target contracts | Proposal payload data in Azorius | Business logic executed by Safe when tx is allowed | Not called directly by guard; included in hash preimage passed to Azorius |

## Guard placement requirement

For the mainnet stack (`Safe 1.3.0` + Azorius module), veto enforcement must be configured as:

1. Deploy `SecurityCouncilAzorius`.
2. Set it as Azorius guard via `Azorius.setGuard(deployedGuard)`.

Setting only Safe guard (`Safe.setGuard`) is insufficient for module-path veto enforcement on Safe `1.3.0`.

## Governance stack contracts for fork proposal tests

These are not called by the guard contract directly, but are used by forked governance-proposal test flows.

| Component | Address | Role |
| --- | --- | --- |
| `LinearERC20Voting` | `0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F` | Azorius voting strategy used to evaluate proposal pass/fail |
| `ShutterToken` | `0xe485E2f1bab389C08721B291f6b59780feC83Fd7` | Vote/delegation token used by voters in proposal tests |

## Address registry (fill per deployment)

Do not rely on memory or chat history for addresses. Record every deployment here and keep it updated in PRs.

| Network | Chain ID | Safe proxy address | Safe singleton address | Safe version | Azorius address | Council address | SecurityCouncilAzorius address | Deployment tx | Deployed at (UTC) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mainnet | `1` | `0x36bD3044ab68f600f6d3e081056F34f2a58432c4` | `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552` | `1.3.0` | `0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e` | `0x3ea731dAF66D6A7980549f90152CD9A761B9c0C0` | `0xb04f553c482063a99b10c55033b56bd50b6b0334` | `TBD` | `TBD` |
| Sepolia | `11155111` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` | `TBD` |

## Deployment input vs operational addresses

Deployment script inputs (`script/DeploySecurityCouncilAzorius.s.sol`):

- required: `COUNCIL_ADDRESS`
- required: `AZORIUS_ADDRESS`

Operational addresses (not constructor inputs, but required for runbooks and incident response):

- Safe address where guard is installed
- Safe singleton (mastercopy) address
- Safe contract version
- Azorius guard address (`Azorius.guard()`)
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
4. Execute and record `Azorius.setGuard(deployedGuard)`.
5. Verify `Azorius.guard() == deployedGuard`.
6. For rotations, append new row and retain old guard address for auditability.
