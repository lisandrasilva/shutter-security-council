// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Enum, SecurityCouncilAzorius, IGuard, IERC165} from "src/SecurityCouncilAzorius.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MockAzorius} from "./MockAzorius.k.sol";
import {KontrolTest} from "test/kontrol/KontrolTest.sol";

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
    function ownerIsNotZero() internal view {
        vm.assertNotEq(guard.owner(), address(0));
    }

    function azoriusIsNotZero() internal view {
        vm.assertNotEq(guard.azorius(), address(0));
    }

    function ownerIsImmutable() internal view {
        vm.assertEq(guard.owner(), council);
    }

    function azoriusIsImmutable() internal view {
        vm.assertEq(guard.azorius(), address(mockAzorius));
    }

    function checkInvariants() internal view {
        ownerIsNotZero();
        azoriusIsNotZero();
        ownerIsImmutable();
        azoriusIsImmutable();
    }

    modifier preserveInvariants() {
        _;
        checkInvariants();
    }

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

    /// @dev Verifies that isProposalVetoed returns true after vetoProposal is called
    ///      on a non-empty proposal, and false when the proposal has no txHashes
    ///      (isProposalVetoed requires at least one entry to return true).
    function test_isProposalVetoed_trueAfterVetoProposal(uint32 proposalId, uint256 slot) external preserveInvariants preserveStorage(slot) {
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

    /// @dev Verifies that vetoProposal reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyCouncilCanVeto(uint32 proposalId) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.vetoProposal(proposalId);
    }

    // =============================================================================
    // unvetoProposal
    // =============================================================================

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

    /// @dev Verifies that isProposalVetoed returns false after unvetoProposal is called,
    ///      regardless of how many txHashes the proposal contains.
    function test_isProposalVetoed_falseAfterUnvetoProposal(uint32 proposalId, uint256 slot) external preserveInvariants preserveStorage(slot) {
        mockAzorius.setSymbolicProposal(proposalId);

        vm.prank(council);
        guard.unvetoProposal(proposalId);

        vm.assertFalse(guard.isProposalVetoed(proposalId));
    }

    /// @dev Verifies that unvetoProposal reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyCouncilCanUnveto(uint32 proposalId) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.unvetoProposal(proposalId);
    }

    // =============================================================================
    // vetoTx
    // =============================================================================

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

    /// @dev Verifies that vetoTx reverts with AlreadyVetoed when the txHash is
    ///      already marked as vetoed in the mapping.
    function test_vetoTxRevertsIfAlreadyVetoed(bytes32 txHash) external {
        vm.assume(guard.vetoedTxHash(txHash));
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.AlreadyVetoed.selector, txHash));
        vm.prank(council);
        guard.vetoTx(txHash);
    }

    /// @dev Verifies that vetoTx reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyCouncilCanVetoTx(bytes32 txHash) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.vetoTx(txHash);
    }

    // =============================================================================
    // unvetoTx
    // =============================================================================

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

    /// @dev Verifies that unvetoTx reverts with NotVetoed when the txHash is not
    ///      currently marked as vetoed in the mapping.
    function test_unvetoTxRevertsIfNotVetoed(bytes32 txHash) external {
        vm.assume(!guard.vetoedTxHash(txHash));
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.NotVetoed.selector, txHash));
        vm.prank(council);
        guard.unvetoTx(txHash);
    }

    /// @dev Verifies that unvetoTx reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyCouncilCanUnvetoTx(bytes32 txHash) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.unvetoTx(txHash);
    }

    // =============================================================================
    // multicall
    // =============================================================================

    /// @dev Verifies that multicall preserves all contract invariants for any symbolic
    ///      sequence of delegatecalls. The specific effects of each call are not checked
    ///      here since the call content is arbitrary.
    function test_multiCall(bytes[] calldata calls, uint256 slot) external preserveInvariants preserveStorage(slot) {
        // TODO: check that the effects of the calls are as expected; non-trivial since the calls can be arbitrary.
        vm.prank(council);
        guard.multicall(calls);
    }

    /// @dev Verifies that multicall reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the council owner.
    function test_onlyCouncilCanMultiCall(bytes[] calldata calls) external {
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.multicall(calls);
    }

    // =============================================================================
    // checkTransaction
    // =============================================================================

    /// @dev Verifies that checkTransaction reverts with TransactionVetoed when the
    ///      txHash computed by azorius.getTxHash for the given parameters is currently
    ///      vetoed. Uses empty calldata since the veto check depends only on the hash.
    function test_checkTransactionRevertsIfVetoed(address to, uint256 value, Enum.Operation operation) external {
        bytes memory data = new bytes(0);
        bytes32 txHash = mockAzorius.getTxHash(to, value, data, operation);
        vm.assume(guard.vetoedTxHash(txHash));
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
        guard.checkTransaction(
            to, value, data, operation,
            0, 0, 0, address(0), payable(address(0)), new bytes(0), address(0)
        );
    }

    /// @dev Verifies that checkTransaction does not revert when the txHash computed by
    ///      azorius.getTxHash for the given parameters is not currently vetoed.
    function test_checkTransactionSucceedsIfNotVetoed(address to, uint256 value, Enum.Operation operation) external view {
        bytes memory data = new bytes(0);
        bytes32 txHash = mockAzorius.getTxHash(to, value, data, operation);
        vm.assume(!guard.vetoedTxHash(txHash));
        guard.checkTransaction(
            to, value, data, operation,
            0, 0, 0, address(0), payable(address(0)), new bytes(0), address(0)
        );
    }

    // =============================================================================
    // checkAfterExecution
    // =============================================================================

    /// @dev Verifies that checkAfterExecution never reverts for any input combination.
    ///      The function is a no-op and must always succeed regardless of the txHash
    ///      or success flag passed by the Azorius module.
    function test_checkAfterExecutionNeverReverts(bytes32 txHash, bool success) external {
        guard.checkAfterExecution(txHash, success);
    }

    // =============================================================================
    // renounceOwnership
    // =============================================================================

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

    /// @dev Verifies that transferOwnership reverts with OwnableInvalidOwner when
    ///      called with address(0), preventing the guard from losing its owner.
    function test_transferOwnershipRevertsForZeroAddress() external {
        vm.prank(council);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        guard.transferOwnership(address(0));
    }

    /// @dev Verifies that after a successful transferOwnership call, owner() returns
    ///      the new owner address.
    function test_transferOwnershipIntegrity(address newOwner, uint256 slot) external preserveInvariants preserveStorage(slot) {
        vm.assume(newOwner != address(0));
        vm.prank(council);
        guard.transferOwnership(newOwner);
        vm.assertEq(guard.owner(), newOwner);
    }

    /// @dev Verifies that transferOwnership reverts with OwnableUnauthorizedAccount
    ///      when called by any address that is not the current council owner.
    function test_nonOwnerCannotTransferOwnership(address randomUser, address newOwner) external {
        vm.assume(randomUser != council);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));
        vm.prank(randomUser);
        guard.transferOwnership(newOwner);
    }

    // =============================================================================
    // supportsInterface
    // =============================================================================

    /// @dev Verifies that supportsInterface returns true for the IGuard interface ID,
    ///      confirming the contract is recognised as a valid Zodiac/Safe guard.
    function test_supportsInterfaceIGuard() external view {
        vm.assertTrue(guard.supportsInterface(type(IGuard).interfaceId));
    }

    /// @dev Verifies that supportsInterface returns true for the IERC165 interface ID
    ///      (0x01ffc9a7), as required by the ERC-165 standard.
    function test_supportsInterfaceIERC165() external view {
        vm.assertTrue(guard.supportsInterface(type(IERC165).interfaceId));
    }

    /// @dev Verifies that supportsInterface returns false for 0xffffffff, which is
    ///      explicitly forbidden by the ERC-165 standard.
    function test_supportsInterfaceRejectsFFFFFFFF() external view {
        vm.assertFalse(guard.supportsInterface(0xffffffff));
    }

}
