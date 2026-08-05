// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Validates a private Confidential Compute settlement result.
/// @dev Backed by TeeRelayedSettlementVerifier, which trusts a registered
/// relayer that independently queried a real Flare Confidential Compute TEE.
interface ISettlementVerifier {
    function verifySettlement(bytes32 policyDigest, bool triggered, uint8 riskTier, bytes calldata proof)
        external
        view
        returns (bool);
}
