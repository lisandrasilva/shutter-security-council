# Execution Plan

This document describes the full deployment and execution sequence for the Shutter DAO governance security mitigation, including the two solution options, their tradeoffs, and blockful's recommendation.

## Context

Shutter DAO (0x36) has a governance vulnerability where the cost to attack the DAO (approximately $100K to reach quorum) is significantly lower than the treasury value ($3M+). The current configuration allows any address holding 1 SHU to submit unlimited proposals with zero timelock, creating an asymmetric attack surface: an attacker needs only ONE proposal to pass, while defenders must vote NO on every malicious proposal.

This plan describes the emergency mitigation sequence and the two paths forward for the community to evaluate.

## Solution Options

### Option A: Security Council (Recommended)

Deploy a veto guard on Azorius that gives a multisig council the ability to block any proposal transaction before execution.

**How it works:**
- `SecurityCouncilAzorius` implements `IGuard` and is installed on the Azorius module through `setGuard()`
- The council (a 5-of-8 Safe multisig) can veto any proposal or individual transaction hash
- The council can veto a proposal at any time — during voting, during the timelock, or even during the execution window. A 2-day timelock is added between vote passing and execution to give the council additional reaction time beyond the voting period, but the timelock is not the only window to act
- When Azorius executes a proposal transaction, it calls `checkTransaction` on its configured guard (`SecurityCouncilAzorius`). The guard computes the tx hash via `Azorius.getTxHash(...)` and reverts with `TransactionVetoed(txHash)` if the hash is vetoed. See `SecurityCouncilAzorius.checkTransaction` in `src/SecurityCouncilAzorius.sol`.

**Pros:**
- **Strong security guarantee.** Every proposal must survive a council review before execution. No malicious proposal can execute without the council allowing it.
- **Resilient to key compromise.** Even if a delegate's key is compromised, the attacker cannot drain the treasury — the council can substitute signer addresses and can veto the malicious proposal with 5-of-8.
- **Post-disclosure safety.** Once the vulnerability details are public, the attack vector is known but the council blocks exploitation regardless, as long as its executed before any attack proposed after it.
- **Enables governance parameter hardening.** With the council as a safety net, the community can take time to adjust parameters (proposer threshold, voting delay, execution period) through normal governance.

**Cons:**
- **Centralization of veto power.** The council can block any proposal, including legitimate ones. This is visible centralization.
- **Council liveness dependency.** If the council becomes unresponsive, no proposals can be vetoed (though this is the less dangerous failure mode — proposals still execute normally).
- **Rogue council risk.** A compromised 5-of-8 multisig could block all governance. 

### Option B: Gated Proposers (Hats Protocol)

Restrict proposal creation to a set of trusted delegates who hold on-chain roles (hats) via Hats Protocol, and raise the token-based proposer threshold to total supply (1B SHU) to prevent unauthorized proposals.

**How it works:**
- A new `LinearERC20VotingWithHatsProposalCreation` strategy is deployed and enabled on Azorius
- Trusted delegates receive proposer hats, allowing them to submit proposals regardless of token holdings
- The old voting strategy's `requiredProposerWeight` is set to 1B SHU (total supply), making it impossible for anyone to propose through the old path
- DecentHats module is temporarily enabled to create the roles, then disabled

**Pros:**
- **Permissioned proposing. Permissionless execution.** Proposal creation is gated, but once submitted, proposals follow the normal voting process. Any token holder can still vote.
- **No veto power.** No single entity can block a proposal that has passed community vote.

**Cons:**
- **No defensive failsafe.** If any proposer submits a malicious proposal and it reaches quorum, there is no mechanism to stop execution. The security council solution has a veto; this does not.
- **Key compromise = direct attack vector.** A compromised delegate key gives the attacker proposal submission capability. Combined with the known arbitrage opportunity (approximately $100K cost vs approximately $3M treasury), this makes every delegate a high-value target.
- **Post-disclosure risk is high.** Once the vulnerability is publicly disclosed, the arbitrage opportunity becomes explicit. Every proposer address becomes a known target for attackers. Without a veto safety net, a single key compromise leads to treasury loss.
- **Governance parameter changes become unnecessary.** If only hat-wearers can propose, raising the proposer threshold or adding voting delays has no additional value.

### Comparison

| Dimension | Option A: Security Council | Option B: Gated Proposers |
|---|---|---|
| Attack surface post-mitigation | Council vetoes any attack. Strong guarantee. | Delegate with hat can still attack. No safety net. |
| Key compromise impact | Compromised key cannot drain treasury (council vetoes) | Compromised key = direct attack vector |
| Post-disclosure risk | Low — attack is public but council blocks execution | High — public vulnerability + known proposer addresses = targets |
| Centralization | Council has veto power (visible centralization) | Proposal gating (less visible but still centralized) |
| Failure mode (malicious insider) | Council blocks malicious proposal | No blocking mechanism |
| Failure mode (rogue council/proposers) | Council blocks legitimate proposals → recoverable via Safe direct execution | Rogue proposer submits attack → no recovery |
| Follow-up governance changes | Needed — threshold, delays, execution window | Not needed (only hat-wearers can propose) |
| Escape path for community | Remove guard via governance proposal | Modify hat assignments via governance |

### Recommendation

**blockful / Anticapture recommends Option A (Security Council only).**

The core reasoning: Option A provides a **defensive failsafe** that Option B does not. After public disclosure of the vulnerability, the arbitrage opportunity becomes common knowledge. In that environment, every delegate in Option B becomes a target, and a single key compromise leads to treasury loss with no recovery mechanism. Option A's veto capability eliminates this risk entirely.

The centralization tradeoff is real but manageable: the community can remove the guard through governance, and the council's veto actions are transparent on-chain. This is temporary centralization to prevent permanent loss.

## Execution Timeline

### Phase 0: Deployment

| Step | Action | Details |
|---|---|---|
| 0.1 | Deploy 1-of-1 Safe | blockful-controlled placeholder multisig. This is the initial council address. |
| 0.2 | Deploy `SecurityCouncilAzorius` | Constructor args: `_council` = Safe from 0.1, `_azorius` = `0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e` |
| 0.3 | Verify contract on Etherscan | Source + constructor args verification |

**Output:** Deployed guard address, verified on explorer.

### Phase 1: Proposal Submission + Vulnerability Demonstration

| Step | Action | Details |
|---|---|---|
| 1.1 | Submit Proposal 1 | Two transactions (atomic): `Azorius.updateTimelockPeriod(14400)` → `Azorius.setGuard(guardAddress)`. Voting starts immediately. |
| 1.2 | Publish forum post | Public disclosure (high-level) of the governance vulnerability, the mitigation plan, both options, and the recommendation. No detailed exploit instructions. |
| 1.3 | Execute spam attack | Submit hundreds of demonstration proposals. Each proposal title references the forum post URL. Purpose: make the vulnerability tangible — delegates see their governance UI flooded with proposals, demonstrating the asymmetric attack vector. |
| 1.4 | DM delegates privately | Direct outreach to target delegates with full vulnerability details, council participation request, and address collection. |

**Timing:** Steps 1.1–1.3 happen in sequence on the same day. The spam attack occurs after Proposal 1 is submitted (voting) but before it passes, demonstrating the vulnerability while it is still exploitable.

**Why spam before the fix passes:** The demonstration needs to show the real risk. If the spam happens after the guard is installed, it doesn't have the same impact. Delegates need to see "this is happening right now, and there's nothing stopping it except the proposal you're voting on."

### Phase 2: Council Formation

| Step | Action | Details |
|---|---|---|
| 2.1 | Form delegate group | Collect confirmed addresses from delegates who agree to participate in the Security Council. |
| 2.2 | Upgrade Safe to 5-of-8 | Add confirmed delegate addresses as signers, set threshold to 5-of-8. |
| 2.3 | Verify multisig configuration | Confirm signer list, threshold, and that the guard's `owner()` matches the Safe address. |

**Note:** The guard uses OpenZeppelin `Ownable`. The `owner()` is the Safe deployed in step 0.1. When signers are added and threshold is changed, the Safe address doesn't change — the guard automatically recognizes the updated multisig.

### Phase 3: Proposal Execution + Community Decision

| Step | Action | Details |
|---|---|---|
| 3.1 | Proposal 1 passes voting | After the 3-day voting period, if quorum + majority are met. |
| 3.2 | Execute Proposal 1 | Timelock is set to 2 days, guard is installed on Azorius. DAO is now protected. |
| 3.3 | Full public disclosure | Detailed vulnerability writeup, attack simulations, economic analysis. Safe to disclose now that the guard is active. |
| 3.4 | Community discussion | Forum thread for delegates and community to discuss Option A vs Option B, long-term governance improvements. |
| 3.5 | Submit follow-up proposal | Based on community decision (see below). |

### Phase 4: Follow-Up (depends on community decision)

#### If Option A (Security Council only) — Recommended path

Submit Proposal 2: Governance Parameters Hardening

| Transaction | Action | Rationale |
|---|---|---|
| 0 | `Azorius.updateExecutionPeriod(50400)` — 7-day execution window | With the 2-day timelock, the total lifecycle grows. 7 days gives proposers enough time to execute without risk of expiry over weekends/holidays. |
| 1 | `LinearERC20Voting.updateRequiredProposerWeight(100_000e18)` — 100K SHU threshold | Raises proposer bar from 1 SHU to 100K SHU (0.01% of supply). High enough to prevent spam, low enough to remain accessible. Based on delegated voting power, not token balance. |

Additional parameters to discuss with the community:
- Voting delay (currently 0)
- Quorum adjustments
- Further threshold tuning

#### If Option B (Gated Proposers)

Submit Proposal 2: Hats Proposal Gating

| Transaction | Action |
|---|---|
| 0 | `Safe.enableModule(DecentHatsModificationModule)` |
| 1 | `DecentHatsModificationModule.createRoleHats(...)` — create proposer hats for confirmed delegates |
| 2 | `Safe.disableModule(SENTINEL, DecentHatsModificationModule)` |
| 3 | `ModuleProxyFactory.deployModule(...)` — deploy `LinearERC20VotingWithHatsProposalCreation` via CREATE2 |
| 4 | `Azorius.enableStrategy(newStrategy)` — enable the new voting strategy |
| 5 | `LinearERC20Voting.updateRequiredProposerWeight(1_000_000_000e18)` — set old strategy threshold to total supply |

**Note:** This is a 6-transaction proposal. When all transactions are passed in a single `executeProposal` call (the standard path), execution is atomic — if any transaction fails, the entire call reverts and no state changes are committed. Partial state is only possible if someone intentionally splits execution across multiple `executeProposal` calls using Azorius's `executionCounter` mechanism.

## Failure Modes and Recovery

### Proposal 1 fails to pass

**Impact:** No guard installed, no timelock. DAO remains vulnerable.
**Recovery:** Re-engage delegates, address concerns, resubmit proposal.

### Proposal 1 passes but execution fails

**Impact:** Unlikely — both transactions target Azorius with simple parameter changes. Since all transactions are passed in a single `executeProposal` call, execution is atomic: if either transaction fails, both revert. No partial state (e.g., timelock set but no guard) is possible in the standard execution path.
**Recovery:** Debug the failure cause, resubmit the proposal.

### Council Safe compromise (post-deployment)

**Impact:** Compromised council could veto all legitimate proposals (governance DoS) or unveto malicious ones.
**Recovery:** Safe signers can execute directly through the Safe (bypassing Azorius module path) to call `Azorius.setGuard(address(0))` and remove the guard. This is the escape hatch.

### Delegate key compromise (Option B only)

**Impact:** Compromised delegate can submit malicious proposals with no veto mechanism to stop execution.
**Recovery:** None before execution. The community would need to submit a counter-proposal to remove the compromised delegate's hat, but this takes the full voting cycle — likely too slow.

### Spam attack proposals pass voting

**Impact:** Demonstration proposals are trivial (e.g., `setNumber(n)` on a test contract). Even if they pass, they execute harmless operations.
**Recovery:** Not needed. By design, spam proposals target a mock contract with no treasury access.

### Option B: Hats proposal execution fails

**Impact:** When all 6 transactions are passed in a single `executeProposal` call (the standard path), execution is atomic — if any transaction fails, all revert. No partial state. However, if execution is intentionally split across multiple calls (using Azorius's partial execution feature), earlier batches would be committed. In that unlikely scenario, recovery would require a new proposal to clean up (e.g., `Safe.disableModule` if DecentHats was left enabled).
**Recovery (standard path):** Debug the failure cause, resubmit the proposal. No cleanup needed since the entire call reverted.

## Verification Checklist

### After Proposal 1 execution

- [ ] `Azorius.guard()` returns the deployed `SecurityCouncilAzorius` address
- [ ] `Azorius.timelockPeriod()` returns `14400`
- [ ] `SecurityCouncilAzorius.owner()` returns the council Safe address
- [ ] `SecurityCouncilAzorius.azorius()` returns `0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e`
- [ ] Council Safe has correct signers and 5-of-8 threshold
- [ ] Test veto + unveto cycle works from the council Safe

### After follow-up proposal execution (Option A)

- [ ] `Azorius.executionPeriod()` returns `50400`
- [ ] `LinearERC20Voting.requiredProposerWeight()` returns `100000000000000000000000` (100K × 10¹⁸)

### After follow-up proposal execution (Option B)

- [ ] New `LinearERC20VotingWithHatsProposalCreation` strategy is enabled on Azorius
- [ ] Old `LinearERC20Voting.requiredProposerWeight()` returns `1000000000000000000000000000` (1B × 10¹⁸)
- [ ] DecentHats module is disabled on the Safe
- [ ] Hat-wearing delegates can submit proposals via the new strategy
- [ ] Non-hat addresses cannot submit proposals via either strategy

## Information Disclosure Sequence

| Phase | What is disclosed | Audience | Risk window |
|---|---|---|---|
| Phase 1.1 | Proposal 1 on-chain (guard + timelock) | Public (on-chain) | Low — proposal content doesn't reveal exploit details |
| Phase 1.2 | Forum post (high-level vulnerability, mitigation plan, options) | Public (forum) | Medium — describes the attack class but not step-by-step instructions |
| Phase 1.3 | Spam attack demonstration | Public (on-chain + governance UI) | Medium — demonstrates the vulnerability in real-time, but proposals are harmless |
| Phase 1.4 | Full vulnerability details (cost, vectors, simulations) | Private (delegates only) | Low — shared only with trusted council candidates |
| Phase 3.3 | Complete technical disclosure | Public | Low — guard is active, attack vector is mitigated |

**Principle:** No detailed exploit instructions are published until the guard is active and the council is operational. The forum post and spam attack create urgency without enabling copycat attacks.

## Dependencies

```
Deploy Safe (0.1)
    └── Deploy Guard (0.2)
            └── Submit Proposal 1 (1.1)
                    ├── Publish Forum Post (1.2)
                    │       └── Execute Spam Attack (1.3)
                    └── DM Delegates (1.4)
                            └── Form Council + Upgrade Safe (2.1–2.3)
                                    └── Proposal 1 Passes + Executes (3.1–3.2)
                                            └── Full Disclosure (3.3)
                                                    └── Community Decision (3.4)
                                                            └── Follow-up Proposal (3.5)
```

## Security Considerations

### Cross-proposal tx-hash collisions

The guard stores veto state by `txHash`, not by `proposalId`. If two proposals contain identical transaction calldata (same target, value, data, operation), they share a hash. Vetoing one blocks both.

**Operational requirement:** Before any veto action, the council must enumerate all active proposals containing the affected tx hash(es) and confirm the intended blast radius.

See: `docs/OPERATIONS.md`

### Guard placement (Safe 1.3.0)

Safe 1.3.0 does not execute transaction guards on the module execution path (`execTransactionFromModule`). The guard must be installed on the Azorius module via `Azorius.setGuard()`, not on the Safe.

See: `docs/OPERATIONS.md`

### Timelock is measured in blocks

`timelockPeriod = 14400` blocks ≈ 2 days at approximately 12s/block (post-merge Ethereum). If block time changes due to a protocol upgrade, the effective timelock duration changes. This is a known characteristic of Azorius, not specific to this guard.

### Council rotation

The guard uses OpenZeppelin `Ownable`. Council rotation is done via `transferOwnership(newCouncil)` — no guard redeployment needed. `renounceOwnership()` is disabled to prevent accidentally leaving the guard without a council.

See: `docs/OPERATIONS.md`
