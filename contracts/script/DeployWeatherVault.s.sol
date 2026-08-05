// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {WeatherVault} from "../src/WeatherVault.sol";
import {TeeRelayedSettlementVerifier} from "../src/mocks/TeeRelayedSettlementVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISettlementVerifier} from "../src/interfaces/ISettlementVerifier.sol";
import {ContractRegistry} from "flare-periphery-0.1.37/src/coston2/ContractRegistry.sol";
import {IAssetManager} from "flare-periphery-0.1.37/src/coston2/IAssetManager.sol";

contract DeployWeatherVault is Script {
    function run() external returns (WeatherVault vault, TeeRelayedSettlementVerifier settlementVerifier) {
        // Looked up dynamically at deploy time, never hardcoded - FXRP's
        // address can change if the underlying AssetManager is upgraded.
        IAssetManager assetManager = ContractRegistry.getAssetManagerFXRP();
        IERC20 fxrp = assetManager.fAsset();
        console.log("FXRP address:", address(fxrp));
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // The deployer is the same account that runs the off-chain weather
        // attestation script and relays settlements, so it is the trusted
        // relayer the verifier checks tx.origin against.
        address relayer = vm.addr(deployerPrivateKey);
        console.log("Settlement relayer:", relayer);

        vm.startBroadcast(deployerPrivateKey);

        settlementVerifier = new TeeRelayedSettlementVerifier(relayer);

        vault = new WeatherVault(fxrp, ISettlementVerifier(address(settlementVerifier)));

        vm.stopBroadcast();
    }
}
