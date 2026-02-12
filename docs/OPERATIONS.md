# Operations Runbook

## Cross-Proposal Tx-Hash Collisions

`SecurityCouncilAzorius` stores veto state by `txHash`:

- `vetoedTxHash[txHash] = true/false`
- not by `proposalId`

Operational implication:

- If proposal A and proposal B contain the same tx hash, vetoing proposal A also blocks execution of that tx hash when reached through proposal B.
- Unvetoing from either proposal clears the shared hash veto globally.

Required operator checks before veto/unveto:

1. Enumerate all active proposals that contain the tx hash(es) being changed.
2. Confirm expected blast radius with governance operators.
3. Record the decision in incident/governance logs.

## Council Rotation Procedure

`council` is immutable. Rotation requires guard replacement.

Recommended procedure:

1. Deploy a new `SecurityCouncilAzorius` with:
   - `COUNCIL_ADDRESS = new council`
   - `AZORIUS_ADDRESS = same production Azorius`
2. Verify source and constructor args.
3. Rehearse on a fork:
   - set new guard via `Azorius.setGuard(newGuard)`
   - execute a known non-vetoed tx (should pass)
   - veto/unveto a known tx hash (should block then restore)
4. Execute governance/safe transaction to switch guard on production Azorius.
5. Post-activation checks:
   - `supportsInterface` and key reads on new guard
   - `Azorius.guard() == newGuard`
   - one live no-op or harmless execution path through guard
6. Keep the old guard address documented for incident response and historic lookups.

## Guard Placement (Safe 1.3.0)

Safe `1.3.0` module transactions (`execTransactionFromModule`) do not execute Safe transaction guard checks.

Operational requirement:

1. Install `SecurityCouncilAzorius` as Azorius module guard (`Azorius.setGuard`).
2. Do not rely on Safe guard wiring alone for proposal-path vetoes.

## Deployment Freeze Controls

Before broadcast:

1. Confirm commit hash, compiler version, and optimization settings.
2. Confirm exact `COUNCIL_ADDRESS` and `AZORIUS_ADDRESS` from approved source of truth.
3. Confirm planned `Azorius.setGuard(deployedGuard)` step and post-check are in rollout plan.
4. Confirm external review sign-off is complete.
