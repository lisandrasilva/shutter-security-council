# Hats Proposal Gating Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Submit the hats proposal-gating governance proposal from a script while sharing one transaction-building implementation with the fork test.

**Architecture:** Extract the proposal constants and transaction builders into a reusable helper contract under `src/proposals/`. Keep the script minimal by only parsing env input and calling `Azorius.submitProposal(...)`. Rewire the fork tests to consume the helper so test and script cannot drift.

**Tech Stack:** Foundry, Solidity `0.8.19`, `forge-std` `Script`, `Test`, `StdJson`

---

### Task 1: Add failing tests for the shared builder path

**Files:**
- Modify: `test/fork/HatsProposalGating.t.sol`
- Create: `test/script/SubmitHatsProposalGating.t.sol`

**Step 1: Write the failing test**

Add tests that expect:
- `HatsProposalGating.t.sol` to source its transaction arrays from a shared helper instead of inline builders.
- `SubmitHatsProposalGating.t.sol` to parse `PROPOSER_HAT_WEARERS` from a JSON array env string into `address[]`.

Example parsing assertion:

```solidity
function test_parseWearersFromJsonEnv() public {
    vm.setEnv("PROPOSER_HAT_WEARERS", "[\"0x000000000000000000000000000000000000cAFe\"]");
    address[] memory wearers = script.exposedWearers();
    assertEq(wearers.length, 1);
    assertEq(wearers[0], address(0xCAFE));
}
```

**Step 2: Run test to verify it fails**

Run: `forge test --match-path test/fork/HatsProposalGating.t.sol --match-path test/script/SubmitHatsProposalGating.t.sol`

Expected: FAIL because the shared helper/script parsing path does not exist yet.

**Step 3: Write minimal implementation**

Do not implement here; this task ends after the intentional failing tests are in place.

**Step 4: Run test to verify it still fails for the expected reason**

Run the same command and confirm the failure is due to missing helper/script symbols rather than a malformed test.

**Step 5: Commit**

Do not commit yet.

### Task 2: Implement the shared proposal helper

**Files:**
- Create: `src/proposals/HatsProposalGatingProposal.sol`
- Modify: `test/fork/HatsProposalGating.t.sol`

**Step 1: Write the failing test**

Use the failing tests from Task 1 as the red step.

**Step 2: Run test to verify it fails**

Run: `forge test --match-path test/fork/HatsProposalGating.t.sol --match-path test/script/SubmitHatsProposalGating.t.sol`

Expected: FAIL because the helper contract is not implemented yet.

**Step 3: Write minimal implementation**

Create `src/proposals/HatsProposalGatingProposal.sol` with:

```solidity
library HatsProposalGatingProposal {
    function buildProposalTransactions(address[] memory wearers)
        internal
        pure
        returns (IAzorius.Transaction[] memory);

    function buildBaseTransactions(address[] memory wearers)
        internal
        pure
        returns (IAzorius.Transaction[] memory);
}
```

Implementation requirements:
- move the hats constants and struct definitions here,
- keep the 5-transaction base flow and 6-transaction full flow,
- expose the hats strategy initializer builder,
- expose the `createRoleHats` calldata builder,
- preserve the current transaction ordering and metadata inputs.

Update the fork test to import and call this helper.

**Step 4: Run test to verify it passes**

Run: `forge test --match-path test/fork/HatsProposalGating.t.sol`

Expected: PASS

**Step 5: Commit**

Do not commit yet.

### Task 3: Implement the submit script using the shared helper

**Files:**
- Create: `script/SubmitHatsProposalGating.s.sol`
- Create or Modify: `test/script/SubmitHatsProposalGating.t.sol`

**Step 1: Write the failing test**

Use the parsing test from Task 1 and add a test for metadata/strategy selection if needed.

**Step 2: Run test to verify it fails**

Run: `forge test --match-path test/script/SubmitHatsProposalGating.t.sol`

Expected: FAIL because the script implementation does not exist yet.

**Step 3: Write minimal implementation**

Create a script that:
- reads `DEPLOYER_PRIVATE_KEY`,
- reads `PROPOSER_HAT_WEARERS`,
- wraps the env string as `{"wearers": <envValue>}`,
- parses `address[]` from `.wearers`,
- reverts if the parsed array is empty,
- builds transactions via `HatsProposalGatingProposal`,
- broadcasts `AZORIUS.submitProposal(address(LINEAR_ERC20_VOTING), hex"", txs, metadata)`.

Use this parsing shape:

```solidity
string memory envJson = vm.envString("PROPOSER_HAT_WEARERS");
string memory wrapped = string.concat('{"wearers":', envJson, "}");
address[] memory wearers = vm.parseJsonAddressArray(wrapped, ".wearers");
```

**Step 4: Run test to verify it passes**

Run: `forge test --match-path test/script/SubmitHatsProposalGating.t.sol`

Expected: PASS

**Step 5: Commit**

Do not commit yet.

### Task 4: Run focused verification and lint checks

**Files:**
- Verify only

**Step 1: Run focused tests**

Run:
- `forge test --match-path test/fork/HatsProposalGating.t.sol`
- `forge test --match-path test/script/SubmitHatsProposalGating.t.sol`

Expected: PASS for all focused suites.

**Step 2: Run broader regression if fast enough**

Run: `forge test`

Expected: PASS, or document any unrelated pre-existing failure before proceeding.

**Step 3: Check diagnostics**

Run Cursor lints for:
- `src/proposals/HatsProposalGatingProposal.sol`
- `script/SubmitHatsProposalGating.s.sol`
- touched tests

Expected: no new diagnostics introduced by the change.

**Step 4: Commit**

Do not commit unless explicitly requested by the user.
