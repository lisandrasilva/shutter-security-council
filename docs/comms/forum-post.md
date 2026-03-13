# [SECURITY] Emergency Governance Hardening — Security Council Guard & Mitigation Plan

**Category:** Governance / Security

---

## TL;DR

Shutter DAO (0x36) has a governance vulnerability where the cost to attack the DAO (approximately $100K to reach quorum) is significantly lower than the treasury value ($3M+). The current configuration allows any address holding 1 SHU to submit unlimited proposals with zero timelock, creating an asymmetric attack surface: an attacker needs only ONE proposal to pass, while defenders must vote NO on every malicious proposal.

We've submitted **the Security Council proposal** to install a veto guard with a 2-day timelock as emergency protection. A follow-up proposal to harden governance parameters is being coordinated with key delegates.

This post explains the vulnerability, the mitigation plan, both solution options we're evaluating, and why the proposal was submitted before this post was published.

---

## Why This Post Comes After the Proposal

This post is being published after the Security Council proposal is already live and voting. That's intentional.

The current governance configuration has **no protective mechanism** — no timelock period, no veto capability, no proposal rate limiting. If we disclosed the vulnerability publicly before a safeguard was in place, we'd be advertising a profitable attack vector (~30x ROI) with no defense active.

Now that the proposal is live, we can disclose the full details — including the attack simulations and the open-source repository. Why? Because any new attack proposed after this point would need to go through the 3-day voting period, by which time the Security Council proposal will have passed and the guard will be active. The defense is in place before any new attack can execute.

**Responsible disclosure sequence:**
- [x] Identify vulnerability
- [x] Coordinate with affected parties
- [x] Research possible fixes and tradeoffs
- [x] Develop, simulate and test fixes
- [x] Audit the fix (blockful hired Cyfrin, [here](https://github.com/blockful/shutter-security-council/blob/main/audits/2026-03-11-cyfrin-shutter-security-council.pdf) is the audit)
- [x] Submit mitigation (Security Council proposal — done)
- [x] Disclose publicly with full details (this post — you're reading it)
- [ ] Post-mortem after proposal executes and guard is in place — full retrospective on the vulnerability, the response, and other historical simulations and facts.

The proposal creates the safety window for disclosure. Even with full knowledge of the attack vector, an attacker cannot execute before the guard is installed.

---

## The Vulnerability

### What's Wrong

0x36 DAO's current governance configuration allows any address holding 1 SHU to submit unlimited proposals with zero timelock, creating an asymmetric attack surface.

**How the attack works:**

1. **Accumulate quorum capability:** Acquire ~$100K worth of SHU (enough to reach the 30M SHU quorum on their own proposals)
2. **Spam proposals:** With 1 SHU proposal threshold and no rate limits, submit hundreds or thousands of malicious proposals
3. **Asymmetric advantage:** Attacker needs ONE proposal to pass (drain treasury), defenders must vote NO on every single one
4. **Treasury drain:** Execute immediately after vote passes (0 timelock), drain ~$3M+ in stablecoins

**The asymmetry:** The attacker needs one proposal to succeed. Defenders need perfect vigilance on every proposal, indefinitely. Fatigue advantage — defenders must maintain perfect vigilance; attacker only needs one window of opportunity.

### Economic Reality

| Factor | Value |
|--------|-------|
| Quorum cost | ~$100K in SHU |
| Proposal cost | 1 SHU (~$0.10) |
| Treasury value | ~$3M+ in stablecoins |
| Attacker profit | ~$2.9M (~30x ROI) |
| Attack duration | 3–7 days (voting period) |

This is not a bug in the smart contracts. It's an emergent property of the governance parameter configuration and economic conditions: low proposal threshold + no rate limiting + no timelock + moderate quorum. Each parameter alone is reasonable. Together, they create an exploitable attack surface.

The economics are overwhelmingly favorable to the attacker. We've validated the attack in controlled simulations on forked mainnet.

We also verified the feasibility of token accumulation: in a three-day period, we were able to purchase nearly 3 million SHU tokens. Since then, the token price has dropped by ~30%. At current prices, accumulating the 30M SHU needed for quorum would be achievable within one to two months — well within a motivated attacker's timeline.

### Current Protection

**None.** There is currently no mechanism to stop this attack once it begins. No rate limits, no veto, no timelock, no proposal screening. Once an attacker reaches quorum and starts spamming, the only defense is voting NO on every proposal. Forever.

---

## Solution Options

We've developed two paths forward. The Security Council proposal (guard + timelock) is the immediate emergency measure and is common to both options. The follow-up approach is what differs.

| Approach | Proposing | Executing |
|---|---|---|
| Security Council (guard + timelock) | Permissionless | Permissioned |
| Gated Proposer (Hats-based role) | Permissioned | Permissionless |

### Option A: Security Council + Parameter Hardening (Recommended)

Deploy a veto guard on Azorius that gives a multisig council the ability to block any proposal transaction before execution, then harden governance parameters (proposer threshold, execution period) as a follow-up.

**How it works:**
- `SecurityCouncilAzorius` implements `IGuard` and is installed on the Azorius module through `setGuard()`
- The council (a 5-of-8 Safe multisig) can veto any proposal or individual transaction hash
- The council can veto a proposal at any time — during voting, during the timelock, or even during the execution window
- A 2-day timelock is added between vote passing and execution to give the council additional reaction time beyond the voting period, but the timelock is not the only window to act
- When Azorius executes a proposal transaction, it calls `checkTransaction` on its configured guard. The guard computes the tx hash via `Azorius.getTxHash(...)` and reverts with `TransactionVetoed(txHash)` if the hash is vetoed

**Pros:**
- **Permissionless proposal creation.** Anyone can still submit proposals — no gating on who can participate in governance.
- **Strong security guarantee.** Every proposal must survive council review before execution. No malicious proposal can execute without the council allowing it.
- **Resilient to key compromise.** Even if a delegate's key is compromised, the attacker cannot drain the treasury — the council can substitute signer addresses and veto the malicious proposal with 5-of-8.
- **Post-disclosure safety.** Once the vulnerability details are public, the attack vector is known but the council blocks exploitation regardless, as long as it's executed before any attack proposed after it.
- **Enables governance parameter hardening.** With the council as a safety net, the community can take time to adjust parameters (proposer threshold, voting delay, execution period) through normal governance.

**Cons:**
- **Permissioned execution.** The council can block any proposal before execution, including legitimate ones. Execution is no longer fully permissionless.
- **Council liveness dependency.** If the council becomes unresponsive, no proposals can be vetoed.
- **Rogue council risk.** A compromised 5-of-8 multisig could block all governance.

### Option B: Gated Proposers (Hats Protocol)

Restrict proposal creation to a set of trusted delegates who hold on-chain roles (hats) via Hats Protocol, and raise the token-based proposer threshold to total supply (1B SHU) to prevent unauthorized proposals. This option uses Decent's existing `LinearERC20VotingWithHatsProposalCreation` module — no custom smart contracts are introduced, so there is no additional smart contract risk beyond what Decent already provides.

**How it works:**
- Decent's `LinearERC20VotingWithHatsProposalCreation` strategy is deployed and enabled on Azorius
- Trusted delegates receive proposer hats, allowing them to submit proposals regardless of token holdings
- The old voting strategy's `requiredProposerWeight` is set to 1B SHU (total supply), making it impossible for anyone to propose through the old path
- DecentHats module is temporarily enabled to create the roles, then disabled

**Pros:**
- **Permissionless execution.** Once a proposal passes voting, it executes without any council or gatekeeper able to block it. No veto power exists.
- **Permissioned proposing reduces spam.** Only hat-wearing delegates can submit proposals, eliminating the spam attack vector at the source.

**Cons:**
- **Permissioned proposal creation.** Only hat-wearing addresses can propose — governance participation is gated.
- **No defensive failsafe.** If a malicious proposal reaches quorum, nothing can stop execution. Unlike the security council approach, there is no veto.
- **Hat wearers can still spam.** A proposer who wears the hat retains the ability to exploit the spam vector — gating only shifts the trust surface, it doesn't eliminate it.
- **Key compromise = direct attack vector.** A compromised delegate key gives proposal submission capability. Combined with the ~$100K cost vs ~$3M treasury arbitrage, every delegate becomes a high-value target.
- **Post-disclosure risk is high.** Once the vulnerability is public, every proposer address is a known target. Without a veto safety net, a single key compromise leads to treasury loss.

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

### Our Recommendation

**blockful / Anticapture recommends Option A (Security Council + Parameter Hardening).**

The core reasoning: Option A provides a **defensive failsafe** that Option B does not. After public disclosure of the vulnerability, the arbitrage opportunity becomes common knowledge. In that environment, every delegate in Option B becomes a target, and a single key compromise leads to treasury loss with no recovery mechanism. Option A's veto capability eliminates this risk entirely.

The centralization tradeoff is real but manageable: the community can remove the guard through governance, and the council's veto actions are transparent on-chain. This is temporary centralization to prevent permanent loss.

---

## The Security Council Proposal: Guard + Timelock (Voting Now)

This is the immediate emergency measure, common to both options above.

### Transaction Sequence

The proposal contains two atomic transactions:

1. `Azorius.updateTimelockPeriod(14400)` — set 2-day timelock (14,400 blocks ≈ 2 days at ~12s/block)
2. `Azorius.setGuard(guardAddress)` — install the Security Council Guard

If either fails, both revert.

### How the Guard Works

```
Proposal vote passes
    ↓
Timelock period (2 days / 14,400 blocks)  ← NEW
    ↓
Execution window opens
    ↓
Proposer calls Azorius.executeProposal()
    ↓
Azorius calls guard.checkTransaction()
    ↓
Guard computes txHash via Azorius.getTxHash(...)
    ↓
If vetoed → REVERT (TransactionVetoed)
If not    → EXECUTE normally
```

**Veto timing:** The council can veto at any time — during voting, during the timelock, or during the execution window. The 2-day timelock provides additional reaction time beyond the voting period, but it is not the only window to act.

### What the Guard Can and Cannot Do

**Can do:**
- `veto(bytes32 txHash)` — Mark a transaction hash as blocked
- `unveto(bytes32 txHash)` — Remove a veto (if added mistakenly)
- `transferOwnership(address newCouncil)` — Rotate council without redeployment

**Cannot do:**
- Cannot access treasury funds
- Cannot execute transactions or move funds
- Cannot approve proposals
- Can **only block** — veto-only power, not executive power

Council actions are transparent — all veto events are visible on-chain.

### Security Council Composition

We propose an **8-member council** of trusted, active delegates:

1. **0xffFA76e332cA7afaae3931cb5d513B7fd681C4CF** — Kleros Labs
2. **0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726** — 5pence
3. **0xDffDb9BeeA2aB3151BcBcf37a01EE8726F22ed94** — d0z3y
4. **0x61C2dAE896f93e5f0f10425914CE7868eE8A0e44** — Mikko Ohtamaa
5. **0x06c2c4dB3776D500636DE63e4F109386dCBa6Ae2** — Jacob Czepluch
6. **0x1F3D3A7A9c548bE39539b39D7400302753E20591** — blockful
7. **0x057928bc52bD08e4D7cE24bF47E01cE99E074048** — DAOplomats
8. **0xB6647e02AE6Dd74137cB80b1C24333852E4AF890** — Lanski

**Multisig configuration:**
- **Threshold:** 5-of-8 (balance of security and responsiveness)
- **Implementation:** Safe Multisig
- **Chain:** Ethereum mainnet (Shutter 0x36 operates on mainnet)
- **Initial deployment:** 1-of-1 Safe (blockful placeholder), upgraded to 5-of-8 after signers confirmation

**Why 5-of-8:**
- Requires majority (>50%) to act — prevents small group from blocking
- Allows 3 members to be unavailable (time zones, holidays, emergencies)
- An attacker would need to compromise 5 separate signers — expensive and difficult

## Follow-Up Proposals (Depends on Community Decision)

With the Security Council Guard as an emergency safety net, the community can decide on structural governance improvements. Whether and how we proceed depends on alignment with stakeholders.

### If Option A (Recommended): Governance Parameters Hardening

**Proposal 2 would contain two transactions:**

| Transaction | Action | Rationale |
|---|---|---|
| 0 | `Azorius.updateExecutionPeriod(50400)` — 7-day execution window | With the 2-day timelock, the total lifecycle grows. 7 days gives proposers enough time to execute without risk of expiry over weekends/holidays. |
| 1 | `LinearERC20Voting.updateRequiredProposerWeight(100_000e18)` — 100K SHU threshold | Raises proposer bar from 1 SHU to 100K SHU (0.01% of supply). High enough to prevent spam, low enough to remain accessible. Based on delegated voting power, not token balance. |

**Additional parameters to discuss with the community:**
- Voting delay (currently 0)
- Quorum adjustments
- Further threshold tuning
- Proposal limit rating

**Governance lifecycle after both proposals:**
```
Submit (100K SHU) → Vote (3 days) → Timelock (2 days) → Execution window (7 days)
                     [Council can veto at any time]
```
Total ~12 days from submission to deadline — comparable to ENS, Arbitrum, and Optimism. Proposals can be executed after 5 days of proposing, if approved and not vetoed.

### If Option B: Gated Proposers via Hats Protocol

**Proposal 2 would contain six transactions:**

| Transaction | Action |
|---|---|
| 0 | `Safe.enableModule(DecentHatsModificationModule)` |
| 1 | `DecentHatsModificationModule.createRoleHats(...)` — create proposer hats for confirmed delegates |
| 2 | `Safe.disableModule(SENTINEL, DecentHatsModificationModule)` |
| 3 | `ModuleProxyFactory.deployModule(...)` — deploy `LinearERC20VotingWithHatsProposalCreation` via CREATE2 |
| 4 | `Azorius.enableStrategy(newStrategy)` — enable the new voting strategy |
| 5 | `LinearERC20Voting.updateRequiredProposerWeight(1_000_000_000e18)` — set old strategy threshold to total supply |

**Important:** Azorius executes transactions sequentially (not atomically). If any transaction fails mid-execution, earlier transactions are already committed. Recovery would require a new proposal to clean up partial state.
---

## Governance Lifecycle Comparison

**Current (vulnerable):**
```
Submit (1 SHU) → Vote (3 days) → Execute immediately
```

**After the Security Council proposal:**
```
Submit (1 SHU) → Vote (3 days) → Timelock (2 days) → Execute
                                  [Council can veto at any time]
```

**After follow-up Option A (if approved):**
```
Submit (100K SHU) → Vote (3 days) → Timelock (2 days) → Execution window (7 days)
                     [Council can veto at any time]
```

## Security Considerations

### Cross-proposal tx-hash collisions
The guard stores veto state by `txHash`, not by `proposalId`. If two proposals contain identical transaction calldata (same target, value, data, operation), they share a hash. Vetoing one blocks both.

**Operational requirement:** Before any veto action, the council must enumerate all active proposals containing the affected tx hash(es) and confirm the intended blast radius.

### Guard placement (Safe 1.3.0)
Safe 1.3.0 does not execute transaction guards on the module execution path (`execTransactionFromModule`). The guard is installed on the Azorius module via `Azorius.setGuard()`, not on the Safe.

### Timelock measured in blocks
`timelockPeriod = 14400` blocks ≈ 2 days at ~12s/block (post-merge Ethereum). If block time changes due to a protocol upgrade, the effective timelock duration changes. This is a known characteristic of Azorius, not specific to this guard.

### Council rotation
The guard uses OpenZeppelin `Ownable`. Council rotation is done via `transferOwnership(newCouncil)` — no guard redeployment needed. `renounceOwnership()` is disabled to prevent accidentally leaving the guard without a council. Alternatively, individual signers can be rotated at the multisig level (adding/removing Safe owners) without touching the guard contract at all.

## Why Trust This Process

### Who We Are

**blockful / Anticapture** — governance security research across 30+ DAOs (ENS, Compound, Uniswap, Arbitrum, Optimism, Scroll, Nouns, Gitcoin, and others). Active delegates in multiple protocols. Public research: [anticapture.com](https://anticapture.com).

We discovered this through routine security research. We've been in communication with key delegates to strengthen the approach before any public disclosure.

### Responsible Disclosure

We do not sell exploits or short tokens before disclosure. We coordinate with affected parties before public disclosure. We provide mitigation paths, not just bug reports.

### What We're Sharing (All Available Now)

- Full source code including attack simulations and exploit demonstrations: [github.com/blockful/shutter-security-council](https://github.com/blockful/shutter-security-council)
- This full explanation of the vulnerability, both options, and our recommendation
- Security Council contract deployed and verified on [Etherscan](https://etherscan.io/address/0xb04f553c482063a99b10c55033b56bd50b6b0334#code)
- Audit report: [link](https://github.com/blockful/shutter-security-council/blob/main/audits/2026-03-11-cyfrin-shutter-security-council.pdf)

With the guard proposal live, we're disclosing fully. The repository is public — you can review the attack simulations, economic analysis, and exploit demonstrations yourself. Any attack attempted after this disclosure would face the Security Council Guard before it could execute.

## Frequently Asked Questions

**Why not just raise the proposal threshold without the Security Council?**

Parameters alone are brittle. If we only raise the threshold, an attacker can still accumulate enough tokens and attack. The Security Council provides defense-in-depth: even if parameters are bypassed, the council can veto.

**How is this different from a multisig controlling the treasury?**

The council does NOT control the treasury. They can only block transactions. They cannot execute, move funds, or approve proposals. Veto-only power, not executive power.

**Why 5-of-8 instead of a higher threshold?**

Balances security and responsiveness. 5-of-8 requires majority agreement while allowing 3 members to be unavailable. Higher thresholds increase compromise resistance but reduce responsiveness — risky when fast veto action is needed.

**Is this vulnerability real?**

The full repository is public — attack simulations, and exploit code are all available for review. Every claim is verifiable. We followed responsible disclosure: the fix proposal went live before we opened the repo.

**Is the Security Council permanent?**

No, it can be remove if delegates wish so (all proposed security council are also major delegates). This is an emergency measure. Once governance parameters are hardened and the community is satisfied with the security posture, the guard can be removed through a governance proposal. Our recommendation is to keep the council in place, but it's up to the DAO to decide.

**Why not wait for community discussion before proposing?**

The vulnerability is active now. Every day without protection is a day of risk. Standard responsible disclosure requires putting the fix in place before detailed public discussion. With the guard proposed, we can now have that discussion safely.

## Timeline

| Date | Event |
|------|-------|
| **Now** | Proposal voting live, this forum post published, aligning with council member suggestions |
| **Mar 13–16** | Proposal voting period (3 days), council Safe upgraded to 5-of-8 |
| **Mar 16** | Proposal execution (if passed) |
| **After Security Council proposal executes** | Post-mortem published: full retrospective on the vulnerability, response, and lessons learned |
| **From now on** | Community discussion on Option A vs Option B |
| **After community decision** | Follow-up proposal submitted based on chosen path |

## How to Participate

**Review the Security Council proposal:** Read the full proposal on Decent. Check the council member selection, guard contract logic, and veto mechanism.

**Vote:** YES if you support emergency protection. NO if you believe the risk doesn't warrant this measure.

## Links

- **Proposal on Decent:** [link]
- **Security Council multisig:** [Safe](https://app.safe.global/transactions/history?safe=eth:0x3ea731dAF66D6A7980549f90152CD9A761B9c0C0)
- **Security Council contract:** [Etherscan](https://etherscan.io/address/0xb04f553c482063a99b10c55033b56bd50b6b0334#code)
- **Source code:** [github.com/blockful/shutter-security-council](https://github.com/blockful/shutter-security-council)
- **Anticapture:** [anticapture.com](https://anticapture.com)

---

🛡️
