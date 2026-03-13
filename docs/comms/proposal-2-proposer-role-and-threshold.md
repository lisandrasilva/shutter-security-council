# PROPOSAL 2: GOVERNANCE PARAMETERS HARDENING

---

## Title

**[Security] Harden Governance Parameters — Execution Period & Proposer Threshold**

---

## Summary

This proposal implements two coordinated governance hardening measures to complete the security mitigation:

1. **Execution Period Extension:** Increase from current value to 50,400 blocks (approximately 7 days), giving proposers adequate time to execute approved proposals without risk of expiry

2. **Proposer Threshold Increase:** Raise the proposal threshold from 1 SHU to 100,000 SHU (0.01% of total supply), creating a meaningful barrier to proposal spam while keeping governance accessible

These measures work together with Proposal 1 (Security Council Guard + Timelock) to create a defense-in-depth security posture.

---

## Motivation

As disclosed in Proposal 1, the current governance configuration creates an asymmetric attack surface:

**The core vulnerability:**
- Any address can create proposals with minimal stake (1 SHU threshold)
- No rate limiting on proposal creation
- Economic incentive for spam attacks (treasury value >> quorum accumulation cost)
- Asymmetric defense: attacker needs ONE proposal to pass, defenders must vote NO on thousands

With Security Council Guard (Proposal 1) providing emergency veto capability and a 2-day timelock, we can now safely implement structural hardening through parameter adjustments.

**Why both measures together:**

- **Execution period extension** ensures proposals don't expire during normal governance cycles (weekends, holidays, coordination delays)
- **Proposer threshold raise** creates a meaningful barrier to spam without gatekeeping participation
- **Together** they raise the cost of attack while keeping governance accessible to legitimate participants

---

## Specification

### Part 1: Execution Period Extension

#### Technical Implementation:

Update Azorius module parameter:  
`executionPeriod = 50400` blocks (approximately 7 days)

#### Current State:

- **Current execution period:** [check current value]
- **New execution period:** 50,400 blocks (~7 days at 12s/block)

#### Effect:

With the 2-day timelock (Proposal 1), the total proposal lifecycle becomes:
- **Voting period:** 3 days
- **Timelock period:** 2 days (between vote passing and execution window opening)
- **Execution window:** 7 days (time available to execute after timelock expires)

**Total:** ~12 days from proposal submission to execution deadline

#### Rationale:

A 7-day execution window provides:
- **Weekend coverage** — proposals don't expire over a single weekend
- **Holiday buffer** — accounts for coordination delays during holidays
- **Geographic distribution** — gives time for global coordination across time zones
- **Security council review** — adequate time for veto consideration without rushing

The extended window makes governance more resilient to normal coordination delays while the security council guard prevents malicious execution.

---

### Part 2: Proposer Threshold Increase

#### Technical Implementation:

Update LinearERC20Voting parameter:  
`requiredProposerWeight = 100000000000000000000000` (100,000 SHU in wei)

#### Current State:

- **Current proposal threshold:** 1 SHU
- **New proposal threshold:** 100,000 SHU (0.01% of 1B total supply)

#### Effect:

- Only addresses with **100,000 SHU of delegated voting power** can submit proposals
- Based on **delegation**, not token balance (proposers use their delegated VP, not holdings)
- Meaningful barrier to spam (requires ~$50k+ at current prices)
- Still accessible to legitimate governance participants

#### Rationale:

**Why 100K SHU?**

Looking at current delegation patterns:
- Top delegates hold millions of SHU in voting power
- Active governance participants easily exceed 100K VP
- This creates a barrier to spam without gatekeeping genuine participation

**Why delegation-based?**

Proposers don't need to hold 100K SHU personally — they need 100K in delegated voting power. This:
- Leverages existing delegation infrastructure
- Rewards governance participation and trust-building
- Allows small token holders to participate through delegation
- Makes spam economically expensive (need to buy VP or build reputation)

**Why not higher?**

The goal is to prevent spam, not to centralize proposal creation. 100K SHU is:
- High enough to prevent casual spam (~$50k cost at current prices)
- Low enough to remain accessible (multiple delegates qualify today)
- Adjustable via future governance if needed

---

## Timeline

- **Proposal posted:** [Date TBD] (after Proposal 1 passes and executes)
- **Voting period:** 3 days (standard 0x36 period)
- **Timelock:** 2 days (from Proposal 1)
- **Execution:** After timelock expires
- **Requires:** Proposal 1 (Security Council Guard + Timelock) to be passed first

---

## How This Completes Mitigation

**The identified attack vector:**
1. Accumulate ~$100k in SHU (reach quorum)
2. Spam thousands of malicious proposals (currently: 1 SHU threshold)
3. Drain ~$3M treasury through governance fatigue

**How the full mitigation stops it:**

- **Proposal 1 (Guard + Timelock):** Council can veto malicious proposals + 2-day review window
- **Proposal 2 Part 1 (Execution Period):** 7-day window prevents legitimate proposals from expiring
- **Proposal 2 Part 2 (Proposer Threshold):** 100K SHU threshold makes spam economically expensive

**Result:** Attack cost rises from ~$100K to ~$150K+ (quorum + proposer threshold), and even if an attacker reaches that threshold, the security council can veto malicious proposals. Defense-in-depth.

---

## Risks and Mitigations

### Risk: 100K SHU threshold excludes smaller participants

**Mitigation:** The threshold is delegation-based, not holding-based. Small token holders can delegate to trusted participants who exceed the threshold. This is already how most governance participants engage (through delegation rather than direct voting).

### Risk: 7-day execution window is too long

**Mitigation:** With the security council guard active, there's minimal risk from extended execution windows — malicious proposals can be vetoed regardless of window length. The extension benefits legitimate governance by preventing expiry over weekends/holidays.

### Risk: Parameters become outdated as token price changes

**Mitigation:** Both parameters can be adjusted through future governance proposals. If 100K SHU becomes too high (or too low) as price changes, the community can vote to adjust.

### Risk: Extended lifecycle slows governance

**Mitigation:** The total lifecycle (~12 days) is comparable to other major DAOs. The security benefits (adequate review time, reduced expiry risk) outweigh the marginal slowdown. Urgent proposals can still move quickly if the community mobilizes.

---

## Dependencies

### This proposal depends on:

**Proposal 1 (Security Council Guard + Timelock)** — Emergency veto capability must be in place before parameter adjustments

**Execution order matters.** Guard first (emergency protection), then parameter hardening (structural improvement).

---

## Long-Term Considerations

This proposal is part of the emergency mitigation sequence. Post-mitigation, the community will:

- **Evaluate optimal parameters** based on actual usage patterns
- **Implement rate limiting mechanisms** (proposals per address per period)
- **Explore reputation-weighted thresholds** (lower barrier for trusted delegates)
- **Consider time-based or stake-based proposal gating** for additional security layers
- **Potentially adjust or remove the security council** as other protections mature

**The goal:** Find sustainable governance parameters that:
- Prevent spam attacks
- Enable community participation
- Maintain decentralization
- Don't require permanent emergency measures

This will be part of the long-term governance discussion after full vulnerability disclosure.

---

## Next Steps

With both proposals in place:

1. ✅ Security Council can veto attacks + 2-day timelock (Proposal 1)
2. ✅ Extended execution window prevents legitimate proposal expiry (Proposal 2 Part 1)
3. ✅ Higher threshold raises spam cost meaningfully (Proposal 2 Part 2)

**DAO is hardened.** We can safely disclose full vulnerability details and begin open community discussion on long-term governance improvements.

---

## Why Now

The vulnerability is active. Every day without protection is a day of risk.

We understand this centralizes veto power temporarily (via Proposal 1's security council). We're asking the community to accept **short-term centralization to prevent permanent loss,** while these parameter improvements provide long-term structural security.

**This is step 2 of 2** in emergency mitigation. Once both proposals execute, we can safely disclose full technical details (attack simulations, profit calculations, exploit demonstrations) and begin open community discussion.

---

## Voting Instructions

- **Vote YES** to harden governance parameters (complete mitigation)
- **Vote NO** if you believe these changes are too restrictive

---

## Links

- **Proposal 1 (Security Council Guard + Timelock):** [link]
- **Forum discussion:** [link]
- **Full technical disclosure (post-execution):** [link]
- **Source code:** github.com/blockful/shutter-security-council

---

## Questions

Happy to address questions in the forum thread or on Discord. Full technical disclosure will be shared after both proposals execute.

**Thank you for your continued attention to Shutter DAO's security.**

---

**Proposed by:** @zeugh (Anticapture / blockful)  
**Research collaboration:** Anticapture team  
**Consultation:** Ethereum Foundation researchers, Shutter core team

**Vote on Decent:** [link]

🛡️

---

*[TONE: Professional, technical, clear that these parameter changes work with the security council as defense-in-depth. Emphasize delegation-based threshold as accessible, not gatekeeping.]*
