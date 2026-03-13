# PRIVATE DELEGATE MESSAGE

---

**Delivery:** Telegram DM to designated delegates  
**Timing:** After the Security Council proposal is posted and voting begins

---

## Subject

**[CONFIDENTIAL] Shutter DAO Security — Full Details + Action Required**

---

Hi, this is a **time-sensitive security issue** — appreciate your attention. You're receiving this message because you've been identified as one of the most aligned and trusted delegates on Shutter DAO.

We've identified a governance vulnerability in 0x36 and have submitted a Security Council proposal as emergency mitigation. The proposal is live and voting now, so we can share the full details. We'd like to ask for your support by joining the Security Council.

---

## The Vulnerability

0x36 DAO is currently vulnerable to a governance capture attack via proposal spam.

### Attack Vector

1. Any address that accumulates **~$100K worth of SHU** can reach quorum on their own proposals
2. With a 1 SHU proposal threshold and no rate limits, submit hundreds or thousands of malicious proposals
3. **Asymmetric advantage:** attacker needs ONE proposal to pass, defenders must vote NO on every single one
4. Execute immediately after vote passes (0 timelock), drain **~$3M+ treasury** in stablecoins

### Economic Reality

| Factor | Value |
|--------|-------|
| Quorum cost | ~$100K in SHU |
| Proposal cost | 1 SHU (~$0.10) |
| Treasury value | ~$3M+ in stablecoins |
| Attacker profit | ~$2.9M (~30x ROI) |

We've validated this attack in controlled simulations on forked mainnet. The repository with attack simulations and exploit demonstrations is public: [github.com/blockful/shutter-security-council](https://github.com/blockful/shutter-security-council)

**The risk is real and immediate.**

---

## The Mitigation

### Security Council Proposal (Voting Now)

The proposal installs a Security Council Guard on Azorius with a 2-day timelock:

1. `Azorius.updateTimelockPeriod(14400)` — 2-day timelock between vote passing and execution
2. `Azorius.setGuard(guardAddress)` — install the veto guard

Both transactions are atomic — if either fails, both revert.

**How the guard works:**
- `SecurityCouncilAzorius` implements `IGuard`, installed on Azorius via `setGuard()`
- The council (5-of-8 Safe multisig) can veto any proposal or individual transaction hash
- When Azorius executes a proposal, it calls `checkTransaction()` on the guard — if the tx hash is vetoed, execution reverts
- The council can veto at any time: during voting, during the timelock, or during the execution window

**What the guard cannot do:**
- Cannot access treasury funds
- Cannot execute transactions or move funds
- Can **only block** — veto-only power, not executive power

### Follow-Up: Community Decision

With the Security Council Guard as an emergency safety net, the community will decide on structural governance improvements. We're evaluating two paths:

**Option A (our recommendation): Security Council + Parameter Hardening**
- Keep the Security Council as a defensive failsafe
- Raise proposer threshold from 1 SHU to 100K SHU (delegation-based)
- Extend execution period to ~7 days
- Permissionless proposals, permissioned execution (council veto, no gates)

**Option B: Gated Proposers via Hats Protocol**
- Restrict proposal creation to hat-wearing delegates
- Raise threshold to 1B SHU (total supply) to block non-role proposals
- Permissioned proposals, permissionless execution (no veto, proposal gate)

**We recommend Option A** because after public disclosure, the arbitrage opportunity becomes common knowledge. In Option B, every proposer becomes a high-value target — a single key compromise can lead to treasury loss with no recovery mechanism. Option A's veto capability eliminates this risk entirely.

The follow-up approach depends on alignment with stakeholders. We want your input on this.

---

## Security Council Composition

We propose an **8-member council** of trusted, active delegates:

1. **0xffFA76e332cA7afaae3931cb5d513B7fd681C4CF** — Kleros Labs
2. **0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726** — 5pence
3. **0xDffDb9BeeA2aB3151BcBcf37a01EE8726F22ed94** — d0z3y
4. **0x61C2dAE896f93e5f0f10425914CE7868eE8A0e44** — Mikko Ohtamaa
5. **0x06c2c4dB3776D500636DE63e4F109386dCBa6Ae2** — Jacob Czepluch
6. **0x1F3D3A7A9c548bE39539b39D7400302753E20591** — blockful
7. **0x057928bc52bD08e4D7cE24bF47E01cE99E074048** — DAOplomats
8. **0xB6647e02AE6Dd74137cB80b1C24333852E4AF890** — Lanski

**Configuration:**
- **Threshold:** 5-of-8
- **Implementation:** Safe Multisig on Ethereum mainnet
- **Initial deployment:** 1-of-1 Safe (blockful placeholder), upgraded to 5-of-8 after signers confirmation

---

## What I Need From You

1. **Confirmation of participation** in the Security Council (reply to this message)
2. **Your preferred address** for the 5-of-8 Safe multisig
3. **Vote YES** on the Security Council proposal when you're ready
4. Join the forum discussion for next steps: [FORUM LINK]()

---

## Your Responsibilities as Council Member

- Monitor proposals for malicious activity
- Vote (5-of-8 threshold) to veto attacks if needed
- Respond within **48 hours** to veto requests (council can act during voting, timelock, or execution window)
- Participate in post-mitigation governance discussions

**The future of this role is for the community to decide.** After the vulnerability is mitigated, the community will decide the future of the Security Council — adjust, remove, or keep with modified scope, or as it is.

---

## Timeline

| Date | Event |
|------|-------|
| **Now** | Security Council proposal voting, this message, forum post published |
| **Mar 13–16** | Voting period (3 days), council Safe upgraded to 5-of-8 |
| **Mar 16** | Proposal execution (if passed) |
| **After execution** | Post-mortem: full retrospective on vulnerability, response, and lessons learned |
| **Ongoing** | Community discussion on Option A vs Option B for follow-up |

---

## Links

- **Security Council proposal on Decent:** [link]
- **Forum post:** [link]
- **Security Council multisig:** [Safe](https://app.safe.global/transactions/history?safe=eth:0x3ea731dAF66D6A7980549f90152CD9A761B9c0C0)
- **Security Council contract:** [Etherscan](https://etherscan.io/address/0xb04f553c482063a99b10c55033b56bd50b6b0334#code)
- **Source code + attack simulations:** [github.com/blockful/shutter-security-council](https://github.com/blockful/shutter-security-council)

---

## Questions?

I'm available via:
- This Telegram thread
- Email: zeugh@blockful.io
- Forum thread

Thank you for being part of this critical security response.

Best,
Zeugh (blockful / Anticapture)
