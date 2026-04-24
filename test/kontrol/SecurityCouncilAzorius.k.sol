// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Enum, SecurityCouncilAzorius, IGuard, IERC165, IAzorius} from "src/SecurityCouncilAzorius.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MockAzorius} from "./MockAzorius.k.sol";
import {KontrolTest} from "test/kontrol/KontrolTest.sol";
// =============================================================================
// SecurityCouncilAzoriusKontrolInvariantTest
//
// Kontrol symbolic execution tests for SecurityCouncilAzorius.
// I-N labels below correspond to the invariants
// T-N labels correspond to properties for each specific function call
//
// Coverage:
//   Invariants: Should hold in every possible state
//                  - Checked after setUp
//                  - Checked after every call to the contract that was able to change the state
//   I-1         ownerIsNotZero
//   I-2         azoriusIsNotZero               
//   I-3         ownerPreservation - check was excluded from transferOwnershipIntegrity test
//   I-4         azoriusIsImmutable
//   I-5         storagePreservation - each function is only able to make the expected modifications to
//                                     the contract, the rest of the storage remains untouched
//   
//   For all the following properties, if the function call succeeds, then the invariants should hold after
//   the function executes and the expected state changes for each specific call occurred
//
//   VetoProposal properties:
//   T-1         test_VetoProposal
//   T-2         test_isProposalVetoed_trueAfterVetoProposal
//   T-3         test_onlyOwnerCanVeto
//
//   UnvetoProposal properties:
//   T-4         test_unvetoProposal
//   T-5         test_isProposalVetoed_falseAfterUnvetoProposal
//   T-6         test_onlyOwnerCanUnveto
//
//   VetoTx properties:
//   T-7         test_vetoTx
//   T-8         test_vetoTxRevertsIfAlreadyVetoed
//   T-9         test_onlyOwnerCanVetoTx
//
//   UnvetoTx properties:
//   T-10        test_unvetoTx
//   T-11        test_unvetoTxRevertsIfNotVetoed
//   T-12        test_onlyOwnerCanUnvetoTx
//
//   Multicall properties:
//   T-13        test_multiCall
//   T-14        test_onlyOwnerCanMultiCall
//
//   CheckTransaction properties:
//   T-15        test_checkTransactionRevertsIfVetoed
//   T-16        test_checkTransactionSucceedsIfNotVetoed
//
//   CheckAfterExecution properties:
//   T-17        test_checkAfterExecutionNeverReverts
//
//   RenounceOwnership properties:
//   T-18        test_renounceOwnershipAlwaysReverts
//
//   TransferOwnership properties:
//   T-19        test_transferOwnershipRevertsForZeroAddress
//   T-20        test_transferOwnershipIntegrity
//   T-21        test_nonOwnerCannotTransferOwnership
//
//   SupportsInterface properties:
//   T-22        test_supportsInterfaceIGuard
//   T-23        test_supportsInterfaceIERC165
//   T-24        test_supportsInterfaceRejectsFFFFFFFF
//
// In progress:
//   T-13        test_multiCall is incomplete. calls: bytes[] is symbolic raw bytes,
//               not a valid ABI-encoded call array, so KEVM cannot dispatch into the
//               individual delegated functions. Storage isolation and per-call effect
//               verification require constructing calls as a symbolic array of properly 
//               ABI-encoded calls to known functions with symbolic arguments.
//
// External Azorius call modeling:
//   getTxHash            Called directly on MockAzorius, which computes
//                        keccak256(abi.encode(to, value, data, operation)).
//                        data is fixed to empty bytes; operation is a fresh symbolic
//                        uint8 constrained to < 2 to stay within Enum.Operation.
//   getProposalTxHashes  Provided by MockAzorius backed by setSymbolicProposal, which
//                        writes fresh symbolic bytes32 values directly into storage via
//                        KEVM cheatcodes to build an unbounded symbolic txHash array.
// =============================================================================

contract SecurityCouncilAzoriusKontrolInvariantTest is KontrolTest {
    // Redeclare events from SecurityCouncilAzorius for vm.expectEmit
    event TxHashVetoed(bytes32 indexed txHash);
    event TxHashUnvetoed(bytes32 indexed txHash);
    event ProposalVetoed(uint32 indexed proposalId, uint256 txHashesLength);
    event ProposalUnvetoed(uint32 indexed proposalId, uint256 txCount);

    SecurityCouncilAzorius internal guard;
    MockAzorius internal mockAzorius;

    address internal council;

    uint256[] changedSlots;

    // Unlike Foundry fuzz tests, which sample a finite number of random inputs,
    // Kontrol proves properties hold for ALL possible initial states and ALL possible
    // inputs simultaneously. kevm.symbolicStorage makes the storage of a given contract
    // symbolic, which means the initial state is arbitrary, so the proof covers every 
    // reachable state of the contract — not just the state produced by the constructor. 
    // Each test then proves its property for every possible transition from that arbitrary
    // starting state.
    function setUp() public {
        council = makeAddr("council");
        mockAzorius = new MockAzorius();
        // Make the storage of the mock Azorius symbolic to allow for symbolic proposals and txHashes.
        kevm.symbolicStorage(address(mockAzorius));
    
        guard = new SecurityCouncilAzorius(council, address(mockAzorius));
        kevm.symbolicStorage(address(guard));
        // Restore _owner (slot 0) to council after making storage symbolic.
        _storeAddress(address(guard), 0, council);

        // We assert that the invariants hold at the end of `setUp` - the initial state of the contract is valid.
        checkInvariants();
    }

    // =============================================================================
    // Invariants
    // =============================================================================
    // I-1
    function ownerIsNotZero() internal view {
        vm.assertNotEq(guard.owner(), address(0));
    }

    // I-2
    function azoriusIsNotZero() internal view {
        vm.assertNotEq(guard.azorius(), address(0));
    }

    // I-3
    function ownerPreservation() internal view {
        vm.assertEq(guard.owner(), council);
    }

    // I-4
    function azoriusIsImmutable() internal view {
        vm.assertEq(guard.azorius(), address(mockAzorius));
    }

    function checkInvariants() internal view {
        ownerIsNotZero();
        azoriusIsNotZero();
        ownerPreservation();
        azoriusIsImmutable();
    }

    modifier preserveInvariants() {
        _;
        checkInvariants();
    }

    // I-5
    modifier preserveStorage(uint256 slot) {
        // Before the call:
        // 1. Store the current value of the symbolic storage slot that we expect not to be modified
        //    by vetoing the proposal. This allows us to check later that only the expected storage variables
        //    accesses are modified.
        uint256 initialValue = _loadUInt256(address(guard), slot);
        
        _;

        // After the call:
        // If the slot is not in the list of expected changed slots, check that its value has not changed to ensure 
        // that only the expected storage variables were modified.
        if (!slotInSlots(slot, changedSlots)) {
            // If the slot is not in the list of expected changed slots, check that its value has not changed to ensure 
            // that only the expected storage variables were modified.
            uint256 finalValue = _loadUInt256(address(guard), slot);
            vm.assertEq(initialValue, finalValue, "Unexpected storage modification");
        }

    }

    function slotInSlots(uint256 slot, uint256[] memory mslots) internal pure returns (bool) {

        for (uint256 i = 0; i < mslots.length;) {
            if (mslots[i] == slot) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    // =============================================================================
    // vetoProposal
    // =============================================================================

    // T-1
    /// @dev Verifies that vetoProposal sets vetoedTxHash to true for every txHash
    ///      belonging to the proposal, and that no other storage slot is modified.
    ///      The proposal is made symbolic so all possible txHash arrays are covered.
    function test_VetoProposal(uint32 proposalId, uint256 slot) external preserveInvariants preserveStorage(slot) {
        mockAzorius.setSymbolicProposal(proposalId);
        ( , bytes32[] memory txHashes, , , ) = mockAzorius.getProposal(proposalId);

        vm.prank(council);
        guard.vetoProposal(proposalId);

        uint256 txsLen = txHashes.length;
        changedSlots = new uint256[](txsLen);
        for (uint256 i = 0; i < txsLen;) {
            vm.assertEq(guard.vetoedTxHash(txHashes[i]), true, "Unexpected vetoed state for txHash");
            changedSlots[i] = uint256(keccak256(abi.encode(txHashes[i], uint256(1)))); // vetoedTxHash mapping is at slot 1
            unchecked {
                ++i;
            }
        }
    }

    // T-2
    /// @dev Verifies that isProposalVetoed returns true after vetoProposal is called
    ///      on a non-empty proposal, and false when the proposal has no txHashes
    ///      (isProposalVetoed requires at least one entry to return true).
    ///      Invariant preservation and storage isolation are already covered by
    ///      test_VetoProposal, so preserveInvariants and preserveStorage are omitted here.
    function test_isProposalVetoed_trueAfterVetoProposal(uint32 proposalId) external {
        mockAzorius.setSymbolicProposal(proposalId);
        bytes32[] memory txHashes = mockAzorius.getProposalTxHashes(proposalId);

        vm.prank(council);
        guard.vetoProposal(proposalId);

        if (txHashes.length > 0) {
            vm.assertTrue(guard.isProposalVetoed(proposalId));
        } else {
            vm.assertFalse(guard.isProposalVetoed(proposalId));
        }
    }

    // T-3
    /// @dev Verifies that vetoProposal reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyOwnerCanVeto(uint32 proposalId) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));

        vm.prank(randomUser);
        guard.vetoProposal(proposalId);
    }

    // =============================================================================
    // unvetoProposal
    // =============================================================================

    // T-4
    /// @dev Verifies that unvetoProposal sets vetoedTxHash to false for every txHash
    ///      belonging to the proposal, and that no other storage slot is modified.
    ///      The proposal is made symbolic so all possible txHash arrays are covered.
    function test_unvetoProposal(uint32 proposalId, uint256 slot) external preserveInvariants preserveStorage(slot) {
        mockAzorius.setSymbolicProposal(proposalId);
        ( , bytes32[] memory txHashes, , , ) = mockAzorius.getProposal(proposalId);

        vm.prank(council);
        guard.unvetoProposal(proposalId);

        uint256 txsLen = txHashes.length;
        changedSlots = new uint256[](txsLen);
        for (uint256 i = 0; i < txsLen;) {
            vm.assertFalse(guard.vetoedTxHash(txHashes[i]));
            changedSlots[i] = uint256(keccak256(abi.encode(txHashes[i], uint256(1)))); // vetoedTxHash mapping is at slot 1
            unchecked {
                ++i;
            }
        }
    }

    // T-5
    /// @dev Verifies that isProposalVetoed returns false after unvetoProposal is called,
    ///      regardless of how many txHashes the proposal contains.
    ///      Invariant preservation and storage isolation are already covered by
    ///      test_unvetoProposal, so preserveInvariants and preserveStorage are omitted here.
    function test_isProposalVetoed_falseAfterUnvetoProposal(uint32 proposalId) external {
        mockAzorius.setSymbolicProposal(proposalId);

        vm.prank(council);
        guard.unvetoProposal(proposalId);

        vm.assertFalse(guard.isProposalVetoed(proposalId));
    }

    // T-6
    /// @dev Verifies that unvetoProposal reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyOwnerCanUnveto(uint32 proposalId) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));

        vm.prank(randomUser);
        guard.unvetoProposal(proposalId);
    }

    // =============================================================================
    // vetoTx
    // =============================================================================

    // T-7
    /// @dev Verifies that vetoTx sets vetoedTxHash[txHash] to true, emits TxHashVetoed,
    ///      and modifies only the expected storage slot.
    ///      Precondition: txHash must not already be vetoed.
    function test_vetoTx(bytes32 txHash, uint256 slot) external preserveInvariants preserveStorage(slot) {
        vm.assume(!guard.vetoedTxHash(txHash));

        vm.expectEmit(true, false, false, false, address(guard));
        emit TxHashVetoed(txHash);

        vm.prank(council);
        guard.vetoTx(txHash);

        vm.assertTrue(guard.vetoedTxHash(txHash));
        changedSlots.push(uint256(keccak256(abi.encode(txHash, uint256(1))))); // vetoedTxHash mapping is at slot 1
    }

    // T-8
    /// @dev Verifies that vetoTx reverts with AlreadyVetoed when the txHash is
    ///      already marked as vetoed in the mapping.
    function test_vetoTxRevertsIfAlreadyVetoed(bytes32 txHash) external {
        vm.assume(guard.vetoedTxHash(txHash));
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.AlreadyVetoed.selector, txHash));
        vm.prank(council);
        guard.vetoTx(txHash);
    }

    // T-9
    /// @dev Verifies that vetoTx reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyOwnerCanVetoTx(bytes32 txHash) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));

        vm.prank(randomUser);
        guard.vetoTx(txHash);
    }

    // =============================================================================
    // unvetoTx
    // =============================================================================

    // T-10
    /// @dev Verifies that unvetoTx sets vetoedTxHash[txHash] to false, emits TxHashUnvetoed,
    ///      and modifies only the expected storage slot.
    ///      Precondition: txHash must currently be vetoed.
    function test_unvetoTx(bytes32 txHash, uint256 slot) external preserveInvariants preserveStorage(slot) {
        vm.assume(guard.vetoedTxHash(txHash));

        vm.expectEmit(true, false, false, false, address(guard));
        emit TxHashUnvetoed(txHash);

        vm.prank(council);
        guard.unvetoTx(txHash);

        vm.assertFalse(guard.vetoedTxHash(txHash));
        changedSlots.push(uint256(keccak256(abi.encode(txHash, uint256(1))))); // vetoedTxHash mapping is at slot 1
    }

    // T-11
    /// @dev Verifies that unvetoTx reverts with NotVetoed when the txHash is not
    ///      currently marked as vetoed in the mapping.
    function test_unvetoTxRevertsIfNotVetoed(bytes32 txHash) external {
        vm.assume(!guard.vetoedTxHash(txHash));
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.NotVetoed.selector, txHash));
        vm.prank(council);
        guard.unvetoTx(txHash);
    }

    // T-12
    /// @dev Verifies that unvetoTx reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyOwnerCanUnvetoTx(bytes32 txHash) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));

        vm.prank(randomUser);
        guard.unvetoTx(txHash);
    }

    // =============================================================================
    // multicall
    // =============================================================================

    // T-13
    /// @dev Verifies that multicall preserves all contract invariants when called by the owner.
    ///      Storage preservation and per-call effect verification are not fully covered:
    ///      bytes[] calldata is symbolic raw bytes, not a valid ABI-encoded call array,
    ///      so KEVM cannot symbolically dispatch to the individual functions being delegated.
    ///      A complete proof would require constructing calls as a symbolic array of
    ///      properly ABI-encoded calls to known functions with symbolic arguments.
    function test_multiCall(bytes[] calldata calls, uint256 slot) external preserveInvariants preserveStorage(slot) {
        // TODO: storage isolation and per-call effects cannot be verified until calls is
        //       constructed as a valid symbolic ABI-encoded call array.
        vm.prank(council);
        guard.multicall(calls);
    }

    // T-14
    /// @dev Verifies that multicall reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyOwnerCanMultiCall(bytes[] calldata calls) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));

        vm.prank(randomUser);
        guard.multicall(calls);
    }

    // =============================================================================
    // checkTransaction
    // =============================================================================

    // T-15
    /// @dev Verifies that checkTransaction reverts with TransactionVetoed when the
    ///      txHash computed by mockAzorius.getTxHash is currently vetoed.
    ///      data is fixed to empty bytes; operation is a fresh symbolic uint8 constrained
    ///      to the valid Enum.Operation range (0 or 1) to avoid spurious path conditions.
    function test_checkTransactionRevertsIfVetoed(address to, uint256 value, uint256 slot) external  preserveInvariants preserveStorage(slot) {
        bytes memory data = new bytes(0);
        uint8 operation = freshUInt8("operation");
        vm.assume(operation < 2);
        bytes32 txHash = mockAzorius.getTxHash(to, value, data, Enum.Operation(operation));
        vm.assume(guard.vetoedTxHash(txHash));
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
        guard.checkTransaction(
            to, value, data, Enum.Operation(operation),
            0, 0, 0, address(0), payable(address(0)), new bytes(0), address(0)
        );
    }

    // T-16
    /// @dev Verifies that checkTransaction does not revert and modifies no storage when
    ///      the txHash computed by mockAzorius.getTxHash is not currently vetoed.
    ///      data is fixed to empty bytes; operation is a fresh symbolic uint8 constrained
    ///      to the valid Enum.Operation range (0 or 1) to avoid spurious path conditions.
    function test_checkTransactionSucceedsIfNotVetoed(address to, uint256 value, uint256 slot) external view preserveInvariants preserveStorage(slot) {
        bytes memory data = new bytes(0);
        uint8 operation = freshUInt8("operation");
        vm.assume(operation < 2);
        bytes32 txHash = mockAzorius.getTxHash(to, value, data, Enum.Operation(operation));
        vm.assume(!guard.vetoedTxHash(txHash));
        guard.checkTransaction(
            to, value, data, Enum.Operation(operation),
            0, 0, 0, address(0), payable(address(0)), new bytes(0), address(0)
        );
    }

    // =============================================================================
    // checkAfterExecution
    // =============================================================================

    // T-17
    /// @dev Verifies that checkAfterExecution never reverts for any input combination
    ///      and that no storage slot is modified. The function is a no-op and must always
    ///      succeed regardless of the txHash or success flag passed by the Azorius module.
    function test_checkAfterExecutionNeverReverts(bytes32 txHash, bool success, uint256 slot) external preserveStorage(slot) {
        guard.checkAfterExecution(txHash, success);
    }

    // =============================================================================
    // renounceOwnership
    // =============================================================================

    // T-18
    /// @dev Verifies that renounceOwnership always reverts with RenounceOwnershipDisabled,
    ///      even when called by the council owner. This prevents the guard from being left
    ///      without an authorized council.
    function test_renounceOwnershipAlwaysReverts() external {
        vm.prank(council);
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.RenounceOwnershipDisabled.selector));
        guard.renounceOwnership();
    }

    // =============================================================================
    // transferOwnership
    // =============================================================================

    // T-19
    /// @dev Verifies that transferOwnership reverts with OwnableInvalidOwner when
    ///      called with address(0), preventing the guard from losing its owner.
    function test_transferOwnershipRevertsForZeroAddress() external {
        vm.prank(council);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        guard.transferOwnership(address(0));
    }

    // T-20
    /// @dev Verifies that after a successful transferOwnership call, owner() returns
    ///      the new owner address.
    function test_transferOwnershipIntegrity(address newOwner, uint256 slot) external preserveStorage(slot) {
        vm.assume(newOwner != address(0));
        vm.prank(council);
        guard.transferOwnership(newOwner);

        // Slot owner is expected to change - preparation for preserveStorage modifier
        changedSlots.push(0);
        
        // Assert expected state change
        vm.assertEq(guard.owner(), newOwner);

        // We cannot call preserveInvariants, because the owner changes, and only this function can change it
        // So instead we only call the other 3 invariants
        ownerIsNotZero();
        azoriusIsNotZero();
        azoriusIsImmutable();
    }

    // T-21
    /// @dev Verifies that transferOwnership reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the current council owner.
    function test_nonOwnerCannotTransferOwnership(address randomUser, address newOwner) external {
        vm.assume(randomUser != council);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));
        vm.prank(randomUser);
        guard.transferOwnership(newOwner);
    }

    // =============================================================================
    // supportsInterface
    // =============================================================================
    // Note: these three tests are fully concrete — the interface IDs are compile-time
    // constants and supportsInterface has no symbolic inputs. They do not benefit from
    // symbolic execution and could be moved to a regular Foundry test file instead.

    // T-22
    /// @dev Verifies that supportsInterface returns true for the IGuard interface ID,
    ///      confirming the contract is recognised as a valid Zodiac/Safe guard.
    function test_supportsInterfaceIGuard() external view {
        vm.assertTrue(guard.supportsInterface(type(IGuard).interfaceId));
    }

    // T-23
    /// @dev Verifies that supportsInterface returns true for the IERC165 interface ID
    ///      (0x01ffc9a7), as required by the ERC-165 standard.
    function test_supportsInterfaceIERC165() external view {
        vm.assertTrue(guard.supportsInterface(type(IERC165).interfaceId));
    }

    // T-24
    /// @dev Verifies that supportsInterface returns false for 0xffffffff, which is
    ///      explicitly forbidden by the ERC-165 standard.
    function test_supportsInterfaceRejectsFFFFFFFF() external view {
        vm.assertFalse(guard.supportsInterface(0xffffffff));
    }

}
