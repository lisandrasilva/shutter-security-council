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

`SecurityCouncilAzorius` now uses OpenZeppelin `Ownable`.

Operational implication:

- The active council address is `owner()`.
- Council rotation does not require guard replacement.
- Existing `vetoedTxHash` state remains in place across `transferOwnership(newCouncil)`.
- `renounceOwnership()` is disabled, so the guard cannot be left without a council owner.

Recommended procedure:

1. Confirm the current guard is the intended production guard:
   - `Azorius.guard() == currentGuard`
   - `SecurityCouncilAzorius(currentGuard).owner() == current council`
2. Rehearse on a fork:
   - call `transferOwnership(newCouncil)` from the current owner
   - confirm `owner() == newCouncil`
   - confirm a previously vetoed tx hash is still vetoed after the transfer
   - confirm the old council can no longer call veto functions
   - confirm the new council can veto/unveto successfully
3. Execute the ownership transfer on production from the current council owner.
4. Post-rotation checks:
   - `SecurityCouncilAzorius(currentGuard).owner() == newCouncil`
   - `Azorius.guard()` is unchanged
   - one known vetoed tx hash is still blocked
   - one harmless owner-only action path is callable by the new council
5. Record the transfer transaction hash and the new owner address in incident/governance logs.

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
