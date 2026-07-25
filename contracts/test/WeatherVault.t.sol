// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {WeatherVault} from "../src/WeatherVault.sol";
import {MockWeatherOracle} from "../src/mocks/MockWeatherOracle.sol";
import {MockDataConnector} from "../src/mocks/MockDataConnector.sol";
import {MockSettlementVerifier} from "../src/mocks/MockSettlementVerifier.sol";
import {IWeatherOracle} from "../src/interfaces/IWeatherOracle.sol";
import {IDataConnector} from "../src/interfaces/IDataConnector.sol";
import {ISettlementVerifier} from "../src/interfaces/ISettlementVerifier.sol";

contract WeatherVaultTest is Test {
    WeatherVault internal vault;
    MockWeatherOracle internal weatherOracle;
    MockDataConnector internal dataConnector;
    MockSettlementVerifier internal settlementVerifier;

    address internal farmer = makeAddr("farmer");
    address internal keeper = makeAddr("keeper");

    bytes32 internal constant KADUNA_REGION = keccak256("KADUNA_NG");
    uint8 internal constant RAINFALL = 0;
    uint128 internal constant THRESHOLD = 50;
    uint128 internal constant PREMIUM = 1 ether;

    uint64 internal coverageEnd;

    function setUp() public {
        weatherOracle = new MockWeatherOracle();
        dataConnector = new MockDataConnector();
        settlementVerifier = new MockSettlementVerifier();

        vault = new WeatherVault(
            IWeatherOracle(address(weatherOracle)),
            IDataConnector(address(dataConnector)),
            ISettlementVerifier(address(settlementVerifier))
        );

        vm.deal(address(this), 100 ether);
        vm.deal(farmer, 10 ether);

        vault.fundPool{value: 20 ether}();

        coverageEnd = uint64(block.timestamp + 30 days);
    }

    function test_CreatePolicyStoresMinimalPublicData() public {
        uint256 policyId = _createRainfallPolicy();

        (
            address storedFarmer,
            bytes32 regionHash,
            uint64 storedCoverageEnd,
            uint128 threshold,
            uint128 premium,
            uint8 parameter,
            WeatherVault.Status status
        ) = vault.policies(policyId);

        assertEq(storedFarmer, farmer);
        assertEq(regionHash, KADUNA_REGION);
        assertEq(storedCoverageEnd, coverageEnd);
        assertEq(threshold, THRESHOLD);
        assertEq(premium, PREMIUM);
        assertEq(parameter, RAINFALL);
        assertEq(uint8(status), uint8(WeatherVault.Status.Active));
    }

    function test_ExecutePayoutWhenBothSourcesAgreeAndTeeApproves() public {
        uint256 policyId = _createRainfallPolicy();

        // Rainfall of 42 mm is below the 50 mm drought threshold.
        weatherOracle.setWeatherReading(
            KADUNA_REGION,
            RAINFALL,
            coverageEnd,
            42
        );

        dataConnector.setVerifiedWeatherReading(
            KADUNA_REGION,
            RAINFALL,
            coverageEnd,
            42
        );

        vm.warp(coverageEnd);

        uint8 riskTier = 1;
        bytes32 digest = vault.getPolicyDigest(policyId, riskTier);
        settlementVerifier.approveSettlement(digest);

        uint256 farmerBalanceBefore = farmer.balance;

        vm.prank(keeper);
        vault.executePayout(policyId, riskTier, hex"");

        // Tier 1 payout = 130% of the policy premium.
        assertEq(farmer.balance, farmerBalanceBefore + 1.3 ether);

        (, , , , , , WeatherVault.Status status) = vault.policies(policyId);
        assertEq(uint8(status), uint8(WeatherVault.Status.Paid));
    }

    function test_RevertsWhenDataSourcesDisagree() public {
        uint256 policyId = _createRainfallPolicy();

        weatherOracle.setWeatherReading(
            KADUNA_REGION,
            RAINFALL,
            coverageEnd,
            42
        );

        dataConnector.setVerifiedWeatherReading(
            KADUNA_REGION,
            RAINFALL,
            coverageEnd,
            45
        );

        vm.warp(coverageEnd);

        vm.expectRevert(WeatherVault.DataSourcesDisagree.selector);
        vault.executePayout(policyId, 1, hex"");
    }

    function test_ClaimExpiredRefundsPremiumWhenNoSettlementOccurs() public {
        uint256 policyId = _createRainfallPolicy();

        uint256 farmerBalanceBefore = farmer.balance;

        vm.warp(uint256(coverageEnd) + 7 days);

        vm.prank(keeper);
        vault.claimExpired(policyId);

        assertEq(farmer.balance, farmerBalanceBefore + PREMIUM);

        (, , , , , , WeatherVault.Status status) = vault.policies(policyId);
        assertEq(uint8(status), uint8(WeatherVault.Status.Expired));
    }

    function _createRainfallPolicy() internal returns (uint256 policyId) {
        vm.prank(farmer);

        policyId = vault.createPolicy{value: PREMIUM}(
            KADUNA_REGION,
            RAINFALL,
            THRESHOLD,
            coverageEnd
        );
    }
}