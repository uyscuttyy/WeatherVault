// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {WeatherVault} from "../src/WeatherVault.sol";
import {MockWeatherOracle} from "../src/mocks/MockWeatherOracle.sol";
import {MockDataConnector} from "../src/mocks/MockDataConnector.sol";
import {MockSettlementVerifier} from "../src/mocks/MockSettlementVerifier.sol";
import {IWeatherOracle} from "../src/interfaces/IWeatherOracle.sol";
import {IDataConnector} from "../src/interfaces/IDataConnector.sol";
import {ISettlementVerifier} from "../src/interfaces/ISettlementVerifier.sol";

contract DeployWeatherVault is Script {
    function run()
        external
        returns (
            WeatherVault vault,
            MockWeatherOracle weatherOracle,
            MockDataConnector dataConnector,
            MockSettlementVerifier settlementVerifier
        )
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        weatherOracle = new MockWeatherOracle();
        dataConnector = new MockDataConnector();
        settlementVerifier = new MockSettlementVerifier();

        vault = new WeatherVault(
            IWeatherOracle(address(weatherOracle)),
            IDataConnector(address(dataConnector)),
            ISettlementVerifier(address(settlementVerifier))
        );

        vm.stopBroadcast();
    }
}