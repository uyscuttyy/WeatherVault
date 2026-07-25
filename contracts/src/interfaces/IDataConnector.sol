// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Interface for independently verified weather data.
/// @dev The demo implementation represents Flare Data Connector verification.
interface IDataConnector {
    /// @return Verified weather reading for a completed coverage period.
    function getVerifiedWeatherReading(
        bytes32 regionHash,
        uint8 parameter,
        uint64 coverageEnd
    ) external view returns (uint256);
}
