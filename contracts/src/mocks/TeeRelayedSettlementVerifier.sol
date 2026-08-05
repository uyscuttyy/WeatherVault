// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISettlementVerifier} from "src/interfaces/ISettlementVerifier.sol";

/// @notice Trusts settlement results relayed from a specific address after
/// that relayer independently queried a real Flare Confidential Compute
/// extension. Uses tx.origin (not msg.sender) since this is called
/// internally by WeatherVault - msg.sender here would be WeatherVault
/// itself. tx.origin carries phishing risk in general-purpose contracts,
/// but is acceptable here since the relayer is a specific automated
/// script under your control, not a general user-facing flow.
contract TeeRelayedSettlementVerifier is ISettlementVerifier {
    address public immutable relayer;

    constructor(address _relayer) {
        relayer = _relayer;
    }

    function verifySettlement(
        bytes32, /* policyDigest */
        bool triggered,
        uint8, /* riskTier */
        bytes calldata /* proof */
    )
        external
        view
        returns (bool)
    {
        return tx.origin == relayer && triggered;
    }
}
