// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {Enum, SecurityCouncilAzorius} from "src/SecurityCouncilAzorius.sol";
import {MockAzorius} from "test/mocks/MockAzorius.sol";
import {MockSafe} from "test/mocks/MockSafe.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

contract SecurityCouncilAzoriusInvariantTest is StdInvariant, Test {
    SecurityCouncilAzorius internal guard;
    MockAzorius internal mockAzorius;
    MockSafe internal safe;
    MockTarget internal target;

    address internal council = makeAddr("council");
    uint256 internal constant MAX_TRACKED_SALTS = 24;

    mapping(uint256 => bool) internal isTrackedSalt;
    uint256[] internal trackedSalts;

    function setUp() public {
        mockAzorius = new MockAzorius();
        guard = new SecurityCouncilAzorius(council, address(mockAzorius));
        safe = new MockSafe();
        target = new MockTarget();
        safe.setGuard(address(guard));

        _trackSalt(1);
        targetContract(address(this));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = this.actionCouncilVetoTx.selector;
        selectors[1] = this.actionCouncilUnvetoTx.selector;
        selectors[2] = this.actionCouncilVetoProposal.selector;
        selectors[3] = this.actionCouncilUnvetoProposal.selector;
        selectors[4] = this.actionCouncilMulticall.selector;

        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    function actionCouncilVetoTx(uint256 saltSeed) external {
        uint256 salt = _normalizeSalt(saltSeed);
        _trackSalt(salt);

        bytes32 txHash = _hashForSalt(salt);
        if (!guard.vetoedTxHash(txHash)) {
            vm.prank(council);
            guard.vetoTx(txHash);
        }
    }

    function actionCouncilUnvetoTx(uint256 saltSeed) external {
        uint256 salt = _normalizeSalt(saltSeed);
        _trackSalt(salt);

        bytes32 txHash = _hashForSalt(salt);
        if (guard.vetoedTxHash(txHash)) {
            vm.prank(council);
            guard.unvetoTx(txHash);
        }
    }

    function actionCouncilVetoProposal(uint32 proposalId, uint8 sizeRaw, uint256 seed) external {
        bytes32[] memory txHashes = _proposalHashes(sizeRaw, seed);
        mockAzorius.setProposal(proposalId, txHashes, address(0xBEEF), 1 days, 3 days, 0);

        vm.prank(council);
        guard.vetoProposal(proposalId);
    }

    function actionCouncilUnvetoProposal(uint32 proposalId, uint8 sizeRaw, uint256 seed) external {
        bytes32[] memory txHashes = _proposalHashes(sizeRaw, seed);
        mockAzorius.setProposal(proposalId, txHashes, address(0xBEEF), 1 days, 3 days, 0);

        vm.prank(council);
        guard.unvetoProposal(proposalId);
    }

    function actionCouncilMulticall(uint256 seed, uint8 stepsRaw) external {
        uint8 steps = uint8(bound(stepsRaw, 1, 8));
        bytes[] memory calls = new bytes[](steps);
        uint256 state = seed;

        for (uint256 i = 0; i < steps; i++) {
            state = uint256(keccak256(abi.encode(state, i)));
            uint256 salt = _normalizeSalt(state);
            _trackSalt(salt);
            bytes32 txHash = _hashForSalt(salt);

            bool preferVeto = (state & 1) == 1;
            bool isVetoed = guard.vetoedTxHash(txHash);
            if (preferVeto && !isVetoed) {
                calls[i] = abi.encodeCall(SecurityCouncilAzorius.vetoTx, (txHash));
            } else if (!preferVeto && isVetoed) {
                calls[i] = abi.encodeCall(SecurityCouncilAzorius.unvetoTx, (txHash));
            } else {
                // Toggle to keep the sequence valid (no double-veto / double-unveto)
                calls[i] = isVetoed
                    ? abi.encodeCall(SecurityCouncilAzorius.unvetoTx, (txHash))
                    : abi.encodeCall(SecurityCouncilAzorius.vetoTx, (txHash));
            }
        }

        vm.prank(council);
        guard.multicall(calls);
    }

    function invariant_vetoedHashAlwaysBlocksCheckTransaction() public {
        uint256 saltsLen = trackedSalts.length;
        for (uint256 i = 0; i < saltsLen; i++) {
            uint256 salt = trackedSalts[i];
            bytes memory callData = _callDataForSalt(salt);
            bytes32 txHash = _hashForSalt(salt);

            if (guard.vetoedTxHash(txHash)) {
                vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
                guard.checkTransaction(
                    address(target),
                    0,
                    callData,
                    Enum.Operation.Call,
                    0,
                    0,
                    0,
                    address(0),
                    payable(address(0)),
                    "",
                    address(mockAzorius)
                );
            }
        }
    }

    function invariant_unvetoedHashesRemainExecutable() public {
        uint256 saltsLen = trackedSalts.length;
        for (uint256 i = 0; i < saltsLen; i++) {
            uint256 salt = trackedSalts[i];
            bytes memory callData = _callDataForSalt(salt);
            bytes32 txHash = _hashForSalt(salt);

            if (guard.vetoedTxHash(txHash)) {
                vm.expectRevert(abi.encodeWithSelector(SecurityCouncilAzorius.TransactionVetoed.selector, txHash));
                safe.execTransactionFromModule(address(target), 0, callData, Enum.Operation.Call, address(mockAzorius));
            } else {
                bool success = safe.execTransactionFromModule(
                    address(target), 0, callData, Enum.Operation.Call, address(mockAzorius)
                );
                assertTrue(success);
                assertEq(target.number(), salt);
            }
        }
    }

    function _proposalHashes(uint8 sizeRaw, uint256 seed) internal returns (bytes32[] memory txHashes) {
        uint8 size = uint8(bound(sizeRaw, 1, 10));
        txHashes = new bytes32[](size);
        uint256 state = seed;

        for (uint256 i = 0; i < size; i++) {
            state = uint256(keccak256(abi.encode(state, i)));
            uint256 salt = _normalizeSalt(state);
            _trackSalt(salt);
            txHashes[i] = _hashForSalt(salt);
        }
    }

    function _callDataForSalt(uint256 salt) internal pure returns (bytes memory) {
        return abi.encodeCall(MockTarget.setNumber, (salt));
    }

    function _hashForSalt(uint256 salt) internal view returns (bytes32) {
        return mockAzorius.hashTx(address(target), 0, _callDataForSalt(salt), Enum.Operation.Call);
    }

    function _normalizeSalt(uint256 saltSeed) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(saltSeed))) % 1_000_000_000 + 1;
    }

    function _trackSalt(uint256 salt) internal {
        if (!isTrackedSalt[salt] && trackedSalts.length < MAX_TRACKED_SALTS) {
            isTrackedSalt[salt] = true;
            trackedSalts.push(salt);
        }
    }
}
