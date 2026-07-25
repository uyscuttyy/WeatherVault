// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISettlementVerifier} from "../interfaces/ISettlementVerifier.sol";

/// @notice Demo stand-in for a Flare Confidential Compute settlement verifier.
/// @dev The admin simulates an approved TEE/FCC attestation.
contract MockSettlementVerifier is ISettlementVerifier {
    address public immutable admin;

    mapping(bytes32 => bool) public approvedSettlements;

    event SettlementApproved(bytes32 indexed policyDigest);

    error NotAdmin();

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    function approveSettlement(bytes32 policyDigest) external onlyAdmin {
        approvedSettlements[policyDigest] = true;
        emit SettlementApproved(policyDigest);
    }

    function verifySettlement(
        bytes32 policyDigest,
        bool,
        uint8,
        bytes calldata
    ) external view returns (bool) {
        return approvedSettlements[policyDigest];
    }
}