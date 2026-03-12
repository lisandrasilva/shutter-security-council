// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Enum, IERC165, IGuard, SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {MockAzorius} from "test/mocks/MockAzorius.sol";

contract SecurityCouncilAzoriusUnitTest is Test {
    event ProposalVetoed(uint32 indexed proposalId, uint256 txCount);
    event ProposalUnvetoed(uint32 indexed proposalId, uint256 txCount);
    event TxHashVetoed(bytes32 indexed txHash);
    event TxHashUnvetoed(bytes32 indexed txHash);
    event GuardDeployed(address indexed council, address indexed azorius);

    SecurityCouncilAzorius internal guard;
    MockAzorius internal mockAzorius;

    address internal council = makeAddr("council");
    address internal attacker = makeAddr("attacker");
    address internal target = makeAddr("target");

    uint32 internal constant PROPOSAL_ID = 1;

    function setUp() public {
        mockAzorius = new MockAzorius();
        guard = new SecurityCouncilAzorius(council, address(mockAzorius));
    }

    function test_constructor_revertsForZeroCouncil() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new SecurityCouncilAzorius(address(0), address(mockAzorius));
    }

    function test_constructor_revertsForZeroAzorius() public {
        vm.expectRevert(SecurityCouncilAzorius.ZeroAddressAzorius.selector);
        new SecurityCouncilAzorius(council, address(0));
    }

    function test_constructor_emitsDeploymentEvent() public {
        vm.recordLogs();
        SecurityCouncilAzorius deployed = new SecurityCouncilAzorius(council, address(mockAzorius));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 guardDeployedTopic = keccak256("GuardDeployed(address,address)");
        bool found;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == guardDeployedTopic) {
                found = true;
                assertEq(address(uint160(uint256(logs[i].topics[1]))), council);
                assertEq(address(uint160(uint256(logs[i].topics[2]))), address(mockAzorius));
                break;
            }
        }

        assertTrue(found);
        assertEq(deployed.owner(), council);
        assertEq(deployed.azorius(), address(mockAzorius));
    }

    function test_vetoProposal_marksAllProposalTransactions() public {
        bytes32 h1 = _hashFor(11);
        bytes32 h2 = _hashFor(22);
        _setProposal(PROPOSAL_ID, _toArray(h1, h2));

        vm.prank(council);
        guard.vetoProposal(PROPOSAL_ID);

        assertTrue(guard.vetoedTxHash(h1));
        assertTrue(guard.vetoedTxHash(h2));
    }

    function test_vetoProposal_emitsOnlyForNewVetoes() public {
        bytes32 h1 = _hashFor(11);
        bytes32 h2 = _hashFor(22);

        bytes32[] memory txs = new bytes32[](3);
        txs[0] = h1;
        txs[1] = h2;
        txs[2] = h1;
        _setProposal(PROPOSAL_ID, txs);

        vm.recordLogs();
        vm.prank(council);
        guard.vetoProposal(PROPOSAL_ID);
        Vm.Log[] memory firstCallLogs = vm.getRecordedLogs();

        assertEq(_countEvent(firstCallLogs, keccak256("TxHashVetoed(bytes32)")), 2);
        (bool foundFirst, uint256 countFirst) =
            _findProposalCount(firstCallLogs, keccak256("ProposalVetoed(uint32,uint256)"), PROPOSAL_ID);
        assertTrue(foundFirst);
        assertEq(countFirst, 2);

        vm.recordLogs();
        vm.prank(council);
        guard.vetoProposal(PROPOSAL_ID);
        Vm.Log[] memory secondCallLogs = vm.getRecordedLogs();

        assertEq(_countEvent(secondCallLogs, keccak256("TxHashVetoed(bytes32)")), 0);
        (bool foundSecond, uint256 countSecond) =
            _findProposalCount(secondCallLogs, keccak256("ProposalVetoed(uint32,uint256)"), PROPOSAL_ID);
        assertTrue(foundSecond);
        assertEq(countSecond, 0);
    }

    function test_unvetoProposal_clearsAllProposalTransactions() public {
        bytes32 h1 = _hashFor(11);
        bytes32 h2 = _hashFor(22);
        _setProposal(PROPOSAL_ID, _toArray(h1, h2));

        vm.prank(council);
        guard.vetoProposal(PROPOSAL_ID);

        vm.prank(council);
        guard.unvetoProposal(PROPOSAL_ID);

        assertFalse(guard.vetoedTxHash(h1));
        assertFalse(guard.vetoedTxHash(h2));
    }

    function test_unvetoProposal_emitsOnlyForPreviouslyVetoedTxs() public {
        bytes32 h1 = _hashFor(11);
        bytes32 h2 = _hashFor(22);

        bytes32[] memory txs = new bytes32[](3);
        txs[0] = h1;
        txs[1] = h2;
        txs[2] = h1;
        _setProposal(PROPOSAL_ID, txs);

        vm.prank(council);
        guard.vetoProposal(PROPOSAL_ID);

        vm.recordLogs();
        vm.prank(council);
        guard.unvetoProposal(PROPOSAL_ID);
        Vm.Log[] memory firstCallLogs = vm.getRecordedLogs();

        assertEq(_countEvent(firstCallLogs, keccak256("TxHashUnvetoed(bytes32)")), 2);
        (bool foundFirst, uint256 countFirst) =
            _findProposalCount(firstCallLogs, keccak256("ProposalUnvetoed(uint32,uint256)"), PROPOSAL_ID);
        assertTrue(foundFirst);
        assertEq(countFirst, 2);

        vm.recordLogs();
        vm.prank(council);
        guard.unvetoProposal(PROPOSAL_ID);
        Vm.Log[] memory secondCallLogs = vm.getRecordedLogs();

        assertEq(_countEvent(secondCallLogs, keccak256("TxHashUnvetoed(bytes32)")), 0);
        (bool foundSecond, uint256 countSecond) =
            _findProposalCount(secondCallLogs, keccak256("ProposalUnvetoed(uint32,uint256)"), PROPOSAL_ID);
        assertTrue(foundSecond);
        assertEq(countSecond, 0);
    }

    function test_vetoTx_revertsIfAlreadyVetoed() public {
        bytes32 txHash = _hashFor(77);
        vm.prank(council);
        guard.vetoTx(txHash);

        vm.prank(council);
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.AlreadyVetoed.selector, txHash));
        guard.vetoTx(txHash);
    }

    function test_unvetoTx_revertsIfNotVetoed() public {
        bytes32 txHash = _hashFor(88);
        vm.prank(council);
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.NotVetoed.selector, txHash));
        guard.unvetoTx(txHash);
    }

    function test_transferOwnership_preservesExistingVetoState() public {
        bytes32 txHash = _hashFor(123);
        bytes32 nextTxHash = _hashFor(456);
        address newCouncil = makeAddr("newCouncil");

        vm.prank(council);
        guard.vetoTx(txHash);

        vm.prank(council);
        (bool transferOk,) = address(guard).call(abi.encodeWithSignature("transferOwnership(address)", newCouncil));
        assertTrue(transferOk, "transferOwnership should succeed");

        (bool ownerOk, bytes memory ownerData) = address(guard).staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(ownerOk, "owner() should exist");
        assertEq(abi.decode(ownerData, (address)), newCouncil);

        assertTrue(guard.vetoedTxHash(txHash));

        vm.prank(council);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", council));
        guard.vetoTx(nextTxHash);

        vm.prank(newCouncil);
        guard.unvetoTx(txHash);

        assertFalse(guard.vetoedTxHash(txHash));
    }

    function test_renounceOwnership_disabled() public {
        vm.prank(council);
        vm.expectRevert(SecurityCouncilAzorius.RenounceOwnershipDisabled.selector);
        guard.renounceOwnership();

        assertEq(guard.owner(), council);
    }

    function test_multicall_batchesCouncilOperations() public {
        bytes32 h1 = _hashFor(1);
        bytes32 h2 = _hashFor(2);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeCall(SecurityCouncilAzorius.vetoTx, (h1));
        calls[1] = abi.encodeCall(SecurityCouncilAzorius.vetoTx, (h2));
        calls[2] = abi.encodeCall(SecurityCouncilAzorius.unvetoTx, (h1));

        vm.prank(council);
        guard.multicall(calls);

        assertFalse(guard.vetoedTxHash(h1));
        assertTrue(guard.vetoedTxHash(h2));
    }

    function test_multicall_bubblesInternalRevert() public {
        bytes32 txHash = _hashFor(1);

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(SecurityCouncilAzorius.unvetoTx, (txHash));

        vm.prank(council);
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.NotVetoed.selector, txHash));
        guard.multicall(calls);
    }

    function test_checkTransaction_revertsWhenTxIsVetoed() public {
        bytes memory callData = abi.encodeWithSignature("setNumber(uint256)", 123);
        bytes32 txHash = mockAzorius.hashTx(target, 0, callData, Enum.Operation.Call);

        vm.prank(council);
        guard.vetoTx(txHash);

        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
        guard.checkTransaction(
            target, 0, callData, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), "", address(0)
        );
    }

    function test_checkTransaction_allowsNonVetoedTx() public view {
        bytes memory callData = abi.encodeWithSignature("setNumber(uint256)", 321);
        guard.checkTransaction(
            target, 0, callData, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), "", address(0)
        );
    }

    function test_isProposalVetoed_returnsFalseForEmptyProposal() public view {
        assertFalse(guard.isProposalVetoed(777));
    }

    function test_isProposalVetoed_requiresAllProposalTransactionsToBeVetoed() public {
        bytes32 h1 = _hashFor(10);
        bytes32 h2 = _hashFor(20);
        _setProposal(PROPOSAL_ID, _toArray(h1, h2));

        vm.prank(council);
        guard.vetoTx(h1);
        assertFalse(guard.isProposalVetoed(PROPOSAL_ID));

        vm.prank(council);
        guard.vetoTx(h2);
        assertTrue(guard.isProposalVetoed(PROPOSAL_ID));
    }

    function test_supportsExpectedInterfaces() public view {
        assertTrue(guard.supportsInterface(type(IGuard).interfaceId));
        assertTrue(guard.supportsInterface(type(IERC165).interfaceId));
        assertFalse(guard.supportsInterface(bytes4(0xffffffff)));
    }

    function test_onlyOwnerCanCallStateChangingFunctions() public {
        bytes[] memory calls = new bytes[](0);
        bytes32 txHash = _hashFor(555);

        vm.startPrank(attacker);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        guard.vetoProposal(PROPOSAL_ID);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        guard.unvetoProposal(PROPOSAL_ID);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        guard.vetoTx(txHash);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        guard.unvetoTx(txHash);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        guard.multicall(calls);
        vm.stopPrank();
    }

    function testFuzz_vetoRoundTrip(bytes32 txHash) public {
        vm.prank(council);
        guard.vetoTx(txHash);
        assertTrue(guard.vetoedTxHash(txHash));

        vm.prank(council);
        guard.unvetoTx(txHash);
        assertFalse(guard.vetoedTxHash(txHash));
    }

    function testFuzz_nonOwnerCannotVeto(address actor, bytes32 txHash) public {
        vm.assume(actor != council);
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", actor));
        guard.vetoTx(txHash);
    }

    function testFuzz_multicall_randomizedSequence(uint256 seed, uint8 steps) public {
        steps = uint8(bound(steps, 1, 20));

        bytes32[] memory candidates = new bytes32[](4);
        candidates[0] = _hashFor(1001);
        candidates[1] = _hashFor(1002);
        candidates[2] = _hashFor(1003);
        candidates[3] = _hashFor(1004);

        bool[] memory expected = new bool[](4);
        bytes[] memory calls = new bytes[](steps);
        uint256 state = seed;

        for (uint256 i = 0; i < steps; i++) {
            state = uint256(keccak256(abi.encode(state, i)));
            uint256 idx = state % candidates.length;
            bool preferVeto = ((state >> 8) & 1) == 1;

            if ((preferVeto && !expected[idx]) || (!preferVeto && expected[idx])) {
                if (preferVeto) {
                    calls[i] = abi.encodeCall(SecurityCouncilAzorius.vetoTx, (candidates[idx]));
                    expected[idx] = true;
                } else {
                    calls[i] = abi.encodeCall(SecurityCouncilAzorius.unvetoTx, (candidates[idx]));
                    expected[idx] = false;
                }
            } else if (expected[idx]) {
                calls[i] = abi.encodeCall(SecurityCouncilAzorius.unvetoTx, (candidates[idx]));
                expected[idx] = false;
            } else {
                calls[i] = abi.encodeCall(SecurityCouncilAzorius.vetoTx, (candidates[idx]));
                expected[idx] = true;
            }
        }

        vm.prank(council);
        guard.multicall(calls);

        for (uint256 i = 0; i < candidates.length; i++) {
            assertEq(guard.vetoedTxHash(candidates[i]), expected[i]);
        }
    }

    function testFuzz_vetoProposal_varyingProposalSizes(uint8 proposalSize, uint256 seed) public {
        proposalSize = uint8(bound(proposalSize, 1, 40));
        bytes32[] memory txHashes = _randomTxHashes(proposalSize, seed);
        _setProposal(PROPOSAL_ID, txHashes);

        vm.prank(council);
        guard.vetoProposal(PROPOSAL_ID);

        for (uint256 i = 0; i < txHashes.length; i++) {
            assertTrue(guard.vetoedTxHash(txHashes[i]));
        }
    }

    function testFuzz_unvetoProposal_varyingProposalSizes(uint8 proposalSize, uint256 seed) public {
        proposalSize = uint8(bound(proposalSize, 1, 40));
        bytes32[] memory txHashes = _randomTxHashes(proposalSize, seed);
        _setProposal(PROPOSAL_ID, txHashes);

        vm.prank(council);
        guard.vetoProposal(PROPOSAL_ID);

        vm.prank(council);
        guard.unvetoProposal(PROPOSAL_ID);

        for (uint256 i = 0; i < txHashes.length; i++) {
            assertFalse(guard.vetoedTxHash(txHashes[i]));
        }
    }

    function _hashFor(uint256 salt) internal view returns (bytes32) {
        bytes memory data = abi.encodeWithSignature("setNumber(uint256)", salt);
        return mockAzorius.hashTx(target, 0, data, Enum.Operation.Call);
    }

    function _setProposal(uint32 proposalId, bytes32[] memory txHashes) internal {
        mockAzorius.setProposal(proposalId, txHashes, makeAddr("strategy"), 1 days, 2 days, 0);
    }

    function _toArray(bytes32 a, bytes32 b) internal pure returns (bytes32[] memory arr) {
        arr = new bytes32[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _randomTxHashes(uint256 length, uint256 seed) internal pure returns (bytes32[] memory txHashes) {
        txHashes = new bytes32[](length);
        uint256 state = seed;
        for (uint256 i = 0; i < length; i++) {
            state = uint256(keccak256(abi.encode(state, i)));
            txHashes[i] = bytes32(state);
        }
    }

    function _countEvent(Vm.Log[] memory logs, bytes32 topic0) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic0) {
                count++;
            }
        }
    }

    function _findProposalCount(Vm.Log[] memory logs, bytes32 topic0, uint32 proposalId)
        internal
        pure
        returns (bool found, uint256 txCount)
    {
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics.length > 1 && logs[i].topics[0] == topic0
                    && uint32(uint256(logs[i].topics[1])) == proposalId
            ) {
                found = true;
                txCount = abi.decode(logs[i].data, (uint256));
            }
        }
    }
}
