## Summary

Install a guard module on Azorius enabling a designated security council to veto malicious proposals before execution. Changes timelock period from 0 to 2 days. This is an emergency security measure in response to identified governance vulnerabilities.

---

## Motivation

Our security research has identified a critical governance vulnerability in 0x36 DAO that requires immediate protective action. The current market valuation of SHU, and the configuration of quorum and proposal permissions on Shutter 0x36, allow for any address with **~$100k worth of SHU** to create any amount of proposals and individually approve them unless defense votes to reject each proposal, while the attacker only needs to vote 1 of them to approve, and could take control of the whole treasury with that. 

A security council guard provides:
- **Emergency veto capability** for governance attacks/malicious proposals
- **Standard practice** in high-value DAOs (ENS, Arbitrum, Optimism)

A timelock of **2 days (14,400 blocks)** gives the security council time to respond to vetoing a proposal after its approval. The council can veto at any time — during voting, during the timelock, or even during the execution window — but the timelock provides an additional buffer beyond the voting period itself.

**This proposal establishes the security foundation that will allow safe disclosure, open discussions, and implementation of future protections.**

---

## Technical Implementation

**Deploy and configure security measures:**

- Deploy `SecurityCouncilAzorius` guard contract with council multisig as `owner()` [DONE]
- Install guard on Azorius module via `setGuard()`
- Set timelock period (`timelockPeriod`) from **0 to 14,400 blocks** (approximately 2 days)

**Transaction sequence (atomic execution):**

1. `Azorius.updateTimelockPeriod(14400)` — set 2-day timelock
2. `Azorius.setGuard(guardAddress)` — install security council guard

---

## Security Council Composition

We propose an **8-member council** of trusted, active delegates:

1. **0xffFA76e332cA7afaae3931cb5d513B7fd681C4CF** - Kleros Labs
2. **0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726** - 5pence
3. **0xDffDb9BeeA2aB3151BcBcf37a01EE8726F22ed94** - d0z3y
4. **0x61C2dAE896f93e5f0f10425914CE7868eE8A0e44** - Mikko Ohtamaa
5. **0x06c2c4dB3776D500636DE63e4F109386dCBa6Ae2** - Jacob Czepluch
6. **0x1F3D3A7A9c548bE39539b39D7400302753E20591** - blockful
7. **0x057928bc52bD08e4D7cE24bF47E01cE99E074048** - DAOplomats
8. **0xB6647e02AE6Dd74137cB80b1C24333852E4AF890** - Lanski

---

## Multisig Configuration

- **Threshold:** 5-of-8 (balance of security and responsiveness)
- **Implementation:** Safe Multisig
- **Chain:** Ethereum mainnet (Shutter 0x36 operates on mainnet)
- **Initial deployment:** 1-of-1 Safe (blockful placeholder), upgraded to 5-of-8 after confirming addresses and availability to participate.

---

## Veto Authority

The security council can veto any proposal or individual transaction before execution if it:

- Threatens treasury security
- Contains malicious calldata
- Is identified as spam or governance attack

**Veto timing:** The council can act during voting, during the timelock period, or during the execution window. The 2-day timelock provides additional reaction time beyond the voting period itself.

**Veto mechanism:** The guard computes a transaction hash for each proposal action. If that hash is vetoed, the transaction reverts when Azorius attempts execution.

---

## Timeline

- **Proposal posted:** Mar 13
- **Voting period:** 3 days (standard 0x36 period)
- **Execution:** Mar 16
- **Full disclosure:** Post-mortem after execution. Details already on repo [blockful/shutter-security-council](https://github.com/blockful/shutter-security-council)

---

## Why This Sequence

Standard responsible disclosure practice requires:

1. Put safeguard in place (this proposal)
2. Coordinate with DAO
3. **Implement fix**
4. **Disclose publicly only after fix is deployed**

## Long-Term Considerations

This security council is an **emergency measure**. Post-mitigation, the DAO can:

- Evaluate governance parameter improvements (proposal thresholds, voting delays, execution periods)
- Consider path to remove or adjust security council as other governance parameters are hardened
- Implement comprehensive governance upgrade to restore fuller decentralization with security

**The goal is not permanent centralization.** It's establishing a security foundation that allows the community to discuss in the open the risks exposed, and decide to keep it, change it or create other defense structures..

## Next Steps

With this proposal in place, we can:

1. Safely disclose the full technical details of the vulnerability
2. Have open community discussion about long-term governance improvements
3. Implement additional protections through subsequent proposals


## Why Now

**Governance vulnerabilities don't wait.** The economic incentive exists today. Every day without protection is a day of risk.

We understand this creates permissioned execution. We're asking the community to adopt this **to prevent permanent loss.**

## Voting Instructions

- **Vote YES** to approve emergency security council implementation
- **Vote NO** if you believe the risk doesn't warrant this measure

## Links

- **Forum discussion:** For security, post will only be made after proposal. In the 0x36 [governance forum](https://shutternetwork.discourse.group/c/shutter-dao/dao-proposals/15).
- **Security Council multisig:** [Safe](https://app.safe.global/transactions/history?safe=eth:0x3ea731dAF66D6A7980549f90152CD9A761B9c0C0)
- **Security Council contract:** [Etherscan](https://etherscan.io/address/0xb04f553c482063a99b10c55033b56bd50b6b0334#code)

## Questions

Happy to address questions in this forum thread. Some technical details of the risk and attack simulations will be withheld until after the mitigation is in place.

**Thank you for your attention to Shutter DAO's security and governance integrity.**
