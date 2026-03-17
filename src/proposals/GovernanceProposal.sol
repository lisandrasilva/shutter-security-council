// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title GovernanceProposal
/// @notice Shared Shutter DAO governance constants.
library GovernanceProposal {
    function AZORIUS() internal pure returns (address) {
        return 0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e;
    }

    function SHUTTER_SAFE() internal pure returns (address) {
        return 0x36bD3044ab68f600f6d3e081056F34f2a58432c4;
    }

    function SHUTTER_TOKEN() internal pure returns (address) {
        return 0xe485E2f1bab389C08721B291f6b59780feC83Fd7;
    }

    function LINEAR_ERC20_VOTING() internal pure returns (address) {
        return 0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F;
    }
}
