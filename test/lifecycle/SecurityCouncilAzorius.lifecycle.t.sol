// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Enum, SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {MockAzorius} from "test/mocks/MockAzorius.sol";
import {MockSafe} from "test/mocks/MockSafe.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

contract SecurityCouncilAzoriusLifecycleTest is Test {
    SecurityCouncilAzorius internal guard;
    MockAzorius internal mockAzorius;
    MockSafe internal safe;
    MockTarget internal target;

    address internal council = makeAddr("council");

    function setUp() public {
        mockAzorius = new MockAzorius();
        guard = new SecurityCouncilAzorius(council, address(mockAzorius));
        safe = new MockSafe();
        target = new MockTarget();
        safe.setGuard(address(guard));
    }

    function test_governanceLifecycle_vetoBlocksExecution_thenUnvetoAllowsExecution() public {
        uint32 proposalId = 42;
        uint256 proposedValue = 1337;
        bytes memory callData = abi.encodeCall(MockTarget.setNumber, (proposedValue));
        bytes32 txHash = mockAzorius.hashTx(address(target), 0, callData, Enum.Operation.Call);

        bytes32[] memory txHashes = new bytes32[](1);
        txHashes[0] = txHash;
        mockAzorius.setProposal(proposalId, txHashes, address(0xBEEF), 1 days, 3 days, 0);

        vm.prank(council);
        guard.vetoProposal(proposalId);

        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
        safe.execTransactionFromModule(address(target), 0, callData, Enum.Operation.Call, address(mockAzorius));
        assertEq(target.number(), 0);

        vm.prank(council);
        guard.unvetoProposal(proposalId);

        bool success =
            safe.execTransactionFromModule(address(target), 0, callData, Enum.Operation.Call, address(mockAzorius));
        assertTrue(success);
        assertEq(target.number(), proposedValue);
    }

    function test_governanceLifecycle_multitxVetoBlocksEachTx() public {
        uint32 proposalId = 77;
        bytes memory callData1 = abi.encodeCall(MockTarget.setNumber, (1));
        bytes memory callData2 = abi.encodeCall(MockTarget.setNumber, (2));

        bytes32 txHash1 = mockAzorius.hashTx(address(target), 0, callData1, Enum.Operation.Call);
        bytes32 txHash2 = mockAzorius.hashTx(address(target), 0, callData2, Enum.Operation.Call);

        bytes32[] memory txHashes = new bytes32[](2);
        txHashes[0] = txHash1;
        txHashes[1] = txHash2;
        mockAzorius.setProposal(proposalId, txHashes, address(0xBEEF), 1 days, 3 days, 0);

        vm.prank(council);
        guard.vetoProposal(proposalId);

        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash1));
        safe.execTransactionFromModule(address(target), 0, callData1, Enum.Operation.Call, address(mockAzorius));

        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash2));
        safe.execTransactionFromModule(address(target), 0, callData2, Enum.Operation.Call, address(mockAzorius));
    }
}
