// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Interface used by WeatherVault to read a settled weather value.
/// @dev The demo implementation will mock Flare FTSOv2 data.
interface IWeatherOracle {
    /// @param regionHash Hash of a public preset region identifier.
    /// @param parameter 0 = rainfall in mm; 1 = temperature in centi-degrees Celsius.
    /// @param coverageEnd Unix timestamp marking the end of the coverage period.
    /// @return Weather reading for that region, parameter, and completed period.
    function getWeatherReading(bytes32 regionHash, uint8 parameter, uint64 coverageEnd) external view returns (uint256);
}
