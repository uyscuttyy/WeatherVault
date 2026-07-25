// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDataConnector} from "../interfaces/IDataConnector.sol";

/// @notice Demo stand-in for a Flare Data Connector verified weather result.
/// @dev In production, this adapter should verify the FDC proof.
contract MockDataConnector is IDataConnector {
    address public immutable admin;

    mapping(bytes32 => uint256) private verifiedReadings;

    event VerifiedWeatherReadingSet(
        bytes32 indexed regionHash,
        uint8 indexed parameter,
        uint64 indexed coverageEnd,
        uint256 value
    );

    error NotAdmin();

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    function setVerifiedWeatherReading(
        bytes32 regionHash,
        uint8 parameter,
        uint64 coverageEnd,
        uint256 value
    ) external onlyAdmin {
        verifiedReadings[_readingKey(regionHash, parameter, coverageEnd)] = value;

        emit VerifiedWeatherReadingSet(regionHash, parameter, coverageEnd, value);
    }

    function getVerifiedWeatherReading(
        bytes32 regionHash,
        uint8 parameter,
        uint64 coverageEnd
    ) external view returns (uint256) {
        return verifiedReadings[_readingKey(regionHash, parameter, coverageEnd)];
    }

    function _readingKey(
        bytes32 regionHash,
        uint8 parameter,
        uint64 coverageEnd
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(regionHash, parameter, coverageEnd));
    }
}