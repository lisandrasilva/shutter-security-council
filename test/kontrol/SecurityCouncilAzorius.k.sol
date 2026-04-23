// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Enum, SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
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

        // We assert that the invariants hold at the end of `setUp` - the initial state of the contract is valid.
        ownerIsNotZero();
        azoriusIsNotZero();
        ownerIsImmutable();
        azoriusIsImmutable();
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

    modifier preserveInvariants() {
        _;
        ownerIsNotZero();
        azoriusIsNotZero();
        ownerIsImmutable();
        azoriusIsImmutable();
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
    // Invariant Preserving Actions
    // =============================================================================
    
    // TODO:
    // - We should also check that for each function that the state changes as expected - 
    //    e.g. that vetoing a proposal sets the vetoed state for the txHashes returned by `getProposal`, 
    //         but this is non-trivial since the txHashes are symbolic and we don't know which ones they are. 
    //         For now we just check the invariants.
    // - Ensure that for each function only the expected storage variables are modified
    //    - e.g. that vetoing a proposal only modifies the vetoed state of the relevant txHashes.

    // We want to test that vetoing a proposal preserves the invariants and that the expected state changes occur. 
    function test_VetoProposal(uint32 proposalId, uint256 slot) external preserveInvariants preserveStorage(slot) {
        // Only the council can veto, so we impersonate it to call the function.
        // We check that the invariants hold after the call to vetoProposal

        // Before the call:
        // 1. We make the proposal symbolic to allow for symbolic txHashes
        mockAzorius.setSymbolicProposal(proposalId);
        // 2. We get the txHashes for the proposal so that we can check later that they are vetoed and that only
        // their vetoed state is modified.
        ( , bytes32[] memory txHashes, , , ) = mockAzorius.getProposal(proposalId);
        
        
        vm.prank(council);
        guard.vetoProposal(proposalId);
        
        // After the call:
        // 1. Check that the state changes as expected
        // 2. Populate the changedSlots array with the storage slots that we expect to be modified by vetoing the 
        // proposal. This allows us to check in the preserveStorage modifier that only the expected storage 
        // variables are modified.
        uint256 txsLen = txHashes.length;
        changedSlots = new uint256[](txsLen);
        for (uint256 i = 0; i < txsLen;) {
            vm.assertEq(guard.vetoedTxHash(txHashes[i]), true, "Unexpected vetoed state for txHash");
            changedSlots[i] = uint256(keccak256(abi.encode(txHashes[i], uint256(0)))); // vetoedTxHash mapping is at slot 0
            unchecked {
                ++i;
            }
        }
    }

    function test_onlyCouncilCanVeto(uint32 proposalId) external {
        // We impersonate a random address that is not the council and attempt to veto.
        // We expect this to revert with the NotCouncil error.
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);
        
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.vetoProposal(proposalId);
    }

    function test_unvetoProposal(uint32 proposalId, uint256 slot) external preserveInvariants preserveStorage(slot) {
        // Only the council can unveto, so we impersonate it to call the function.
        // We check that the invariants hold after the call to unvetoProposal
        mockAzorius.setSymbolicProposal(proposalId);
        ( , bytes32[] memory txHashes, , , ) = mockAzorius.getProposal(proposalId);

        //vm.expectEmit(true, false, false, false, address(guard));
        //emit ProposalUnvetoed(proposalId, txsLen);
        
        vm.prank(council);
        guard.unvetoProposal(proposalId);
        
        uint256 txsLen = txHashes.length;
        changedSlots = new uint256[](txsLen);
        for (uint256 i = 0; i < txsLen;) {
            vm.assertFalse(guard.vetoedTxHash(txHashes[i]));
            changedSlots[i] = uint256(keccak256(abi.encode(txHashes[i], uint256(0)))); // vetoedTxHash mapping is at slot 0
            unchecked {
                ++i;
            }
        }
    }

    function test_onlyCouncilCanUnveto(uint32 proposalId) external {
        // We impersonate a random address that is not the council and attempt to unveto. 
        // We expect this to revert with the NotCouncil error.
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);
        
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.unvetoProposal(proposalId);
    }

    function test_vetoTx(bytes32 txHash, uint256 slot) external preserveInvariants preserveStorage(slot) {
        // Only the council can veto a tx, so we impersonate it to call the function.
        // We check that the invariants hold after the call to vetoTx
        vm.assume(!guard.vetoedTxHash(txHash));

        vm.expectEmit(true, false, false, false, address(guard));
        emit TxHashVetoed(txHash);

        vm.prank(council);
        guard.vetoTx(txHash);
        
        vm.assertTrue(guard.vetoedTxHash(txHash));
        changedSlots.push(uint256(keccak256(abi.encode(txHash, uint256(0))))); // vetoedTxHash mapping is at slot 0
    }

    function test_onlyCouncilCanVetoTx(bytes32 txHash) external {
        // We impersonate a random address that is not the council and attempt to veto a tx directly. 
        // We expect this to revert with the NotCouncil error.
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);
        
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.vetoTx(txHash);
    }

    function test_unvetoTx(bytes32 txHash, uint256 slot) external preserveInvariants preserveStorage(slot) {
        // Only the council can unveto a tx, so we impersonate it to call the function.
        // We check that the invariants hold after the call to unvetoTx
        vm.assume(guard.vetoedTxHash(txHash));
        vm.expectEmit(true, false, false, false, address(guard));
        emit TxHashUnvetoed(txHash);

        vm.prank(council);
        guard.unvetoTx(txHash);
        
        vm.assertFalse(guard.vetoedTxHash(txHash));
        changedSlots.push(uint256(keccak256(abi.encode(txHash, uint256(0))))); // vetoedTxHash mapping is at slot 0
    }

    function test_unvetoTxThatIsNotVetoed(bytes32 txHash) external {
        // Unvetoing a tx that is not vetoed should be a no-op and should not revert. We impersonate the council to call the function and check that the invariants hold.
        vm.assume(!guard.vetoedTxHash(txHash));
        vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.NotVetoed.selector, txHash));
        vm.prank(council);
        guard.unvetoTx(txHash);
    }

    function test_onlyCouncilCanUnvetoTx(bytes32 txHash) external {
        // We impersonate a random address that is not the council and attempt to unveto a tx directly. 
        // We expect this to revert with the NotCouncil error.
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);
        
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.unvetoTx(txHash);
    }

    function test_multiCall(bytes[] calldata calls) external preserveInvariants {
        // Only the council can call multicall, so we impersonate it to call the function.
        // We check that the invariants hold after the call to multicall
        // TODO: We should also check that the effects of the calls are as expected, but this is non-trivial since the calls can be arbitrary. For now we just check the invariants.
        vm.prank(council);
        guard.multicall(calls);
    }

    function test_onlyCouncilCanMultiCall(bytes[] calldata calls) external {
        // We impersonate a random address that is not the council and attempt to call multicall. 
        // We expect this to revert with the NotCouncil error.
        address randomUser = kevm.freshAddress();
        vm.assume(randomUser != council);
        
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector));

        vm.prank(randomUser);
        guard.multicall(calls);
    }

}
