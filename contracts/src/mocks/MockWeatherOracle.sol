// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWeatherOracle} from "../interfaces/IWeatherOracle.sol";

/// @notice Demo stand-in for an FTSOv2 weather feed.
/// @dev Replace with a production Flare FTSOv2 adapter for deployment.
contract MockWeatherOracle is IWeatherOracle {
    address public immutable admin;

    mapping(bytes32 => uint256) private readings;

    event WeatherReadingSet(
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

    function setWeatherReading(
        bytes32 regionHash,
        uint8 parameter,
        uint64 coverageEnd,
        uint256 value
    ) external onlyAdmin {
        readings[_readingKey(regionHash, parameter, coverageEnd)] = value;

        emit WeatherReadingSet(regionHash, parameter, coverageEnd, value);
    }

    function getWeatherReading(
        bytes32 regionHash,
        uint8 parameter,
        uint64 coverageEnd
    ) external view returns (uint256) {
        return readings[_readingKey(regionHash, parameter, coverageEnd)];
    }

    function _readingKey(
        bytes32 regionHash,
        uint8 parameter,
        uint64 coverageEnd
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(regionHash, parameter, coverageEnd));
    }
}