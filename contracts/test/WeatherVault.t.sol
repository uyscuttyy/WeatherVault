// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {WeatherVault} from "../src/WeatherVault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {TeeRelayedSettlementVerifier} from "../src/mocks/TeeRelayedSettlementVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISettlementVerifier} from "../src/interfaces/ISettlementVerifier.sol";
import {IWeb2Json} from "flare-periphery-0.1.37/src/coston2/IWeb2Json.sol";
import {IFdcVerification} from "flare-periphery-0.1.37/src/coston2/IFdcVerification.sol";
import {IWeb2JsonVerification} from "flare-periphery-0.1.37/src/coston2/IWeb2JsonVerification.sol";

contract WeatherVaultTest is Test {
    address internal constant FLARE_CONTRACT_REGISTRY_ADDRESS = 0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019;

    WeatherVault internal vault;
    MockERC20 internal fxrp;
    TeeRelayedSettlementVerifier internal settlementVerifier;
    address internal fdcVerificationMock;

    address internal farmer = makeAddr("farmer");
    address internal keeper = makeAddr("keeper");

    string internal constant KADUNA_REGION = "Kaduna, Nigeria";
    bytes32 internal constant KADUNA_REGION_HASH = keccak256(bytes(KADUNA_REGION));
    uint8 internal constant RAINFALL = 0;
    uint128 internal constant THRESHOLD = 50;

    // FXRP has 6 decimals - 1 FXRP = 1_000000, not 1e18.
    uint128 internal constant PREMIUM = 1_000000;

    uint64 internal coverageEnd;

    function setUp() public {
        fxrp = new MockERC20();
        // The keeper is the trusted relayer that fronts FDC-backed settlement
        // results; the verifier checks tx.origin against it.
        settlementVerifier = new TeeRelayedSettlementVerifier(keeper);
        vault = new WeatherVault(IERC20(address(fxrp)), ISettlementVerifier(address(settlementVerifier)));
        fdcVerificationMock = makeAddr("fdcVerification");

        fxrp.mint(address(this), 100_000000);
        fxrp.mint(farmer, 10_000000);

        fxrp.approve(address(vault), 20_000000);
        vault.fundPool(20_000000);

        vm.prank(farmer);
        fxrp.approve(address(vault), type(uint256).max);

        coverageEnd = uint64(block.timestamp + 30 days);
    }

    function test_CreatePolicyPullsFxrpPremium() public {
        uint256 farmerBalanceBefore = fxrp.balanceOf(farmer);

        uint256 policyId = _createRainfallPolicy();

        assertEq(fxrp.balanceOf(farmer), farmerBalanceBefore - PREMIUM);
        assertEq(fxrp.balanceOf(address(vault)), 20_000000 + PREMIUM);

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
        assertEq(regionHash, KADUNA_REGION_HASH);
        assertEq(storedCoverageEnd, coverageEnd);
        assertEq(threshold, THRESHOLD);
        assertEq(premium, PREMIUM);
        assertEq(parameter, RAINFALL);
        assertEq(uint8(status), uint8(WeatherVault.Status.Active));
    }

    function test_ExecutePayoutPaysFxrpWhenFdcProofVerifiesAndTeeApproves() public {
        uint256 policyId = _createRainfallPolicy();
        vm.warp(coverageEnd);

        IWeb2Json.Proof memory proof = _buildWeatherProof(KADUNA_REGION, coverageEnd, 42);
        _mockFdcVerification(true);

        uint8 riskTier = 1;

        uint256 farmerBalanceBefore = fxrp.balanceOf(farmer);

        // Two-arg prank so tx.origin (not just msg.sender) is the keeper, which
        // is what TeeRelayedSettlementVerifier checks against its relayer.
        vm.prank(keeper, keeper);
        vault.executePayout(policyId, riskTier, proof, hex"");

        // Tier 1 payout = 130% of the policy premium.
        assertEq(fxrp.balanceOf(farmer), farmerBalanceBefore + 1_300000);

        (,,,,,, WeatherVault.Status status) = vault.policies(policyId);
        assertEq(uint8(status), uint8(WeatherVault.Status.Paid));
    }

    function test_RevertsWhenFdcProofFailsVerification() public {
        uint256 policyId = _createRainfallPolicy();
        vm.warp(coverageEnd);

        IWeb2Json.Proof memory proof = _buildWeatherProof(KADUNA_REGION, coverageEnd, 42);
        _mockFdcVerification(false);

        vm.expectRevert(WeatherVault.InvalidWeatherProof.selector);
        vault.executePayout(policyId, 1, proof, hex"");
    }

    function test_RevertsWhenProofRegionDoesNotMatchPolicy() public {
        uint256 policyId = _createRainfallPolicy();
        vm.warp(coverageEnd);

        IWeb2Json.Proof memory proof = _buildWeatherProof("Kano, Nigeria", coverageEnd, 42);
        _mockFdcVerification(true);

        vm.expectRevert(WeatherVault.RegionMismatch.selector);
        vault.executePayout(policyId, 1, proof, hex"");
    }

    function test_ClaimExpiredRefundsFxrpPremiumWhenNoSettlementOccurs() public {
        uint256 policyId = _createRainfallPolicy();

        uint256 farmerBalanceBefore = fxrp.balanceOf(farmer);

        vm.warp(uint256(coverageEnd) + 7 days);

        vm.prank(keeper);
        vault.claimExpired(policyId);

        assertEq(fxrp.balanceOf(farmer), farmerBalanceBefore + PREMIUM);

        (,,,,,, WeatherVault.Status status) = vault.policies(policyId);
        assertEq(uint8(status), uint8(WeatherVault.Status.Expired));
    }

    function _createRainfallPolicy() internal returns (uint256 policyId) {
        vm.prank(farmer);

        policyId = vault.createPolicy(KADUNA_REGION_HASH, RAINFALL, THRESHOLD, coverageEnd, PREMIUM);
    }

    function _buildWeatherProof(string memory region, uint64 observedAt, uint256 value)
        internal
        pure
        returns (IWeb2Json.Proof memory proof)
    {
        bytes memory encoded =
            abi.encode(WeatherVault.WeatherReading({region: region, observedAt: observedAt, value: value}));

        IWeb2Json.Response memory response = IWeb2Json.Response({
            attestationType: bytes32(0),
            sourceId: bytes32(0),
            votingRound: 0,
            lowestUsedTimestamp: 0,
            requestBody: IWeb2Json.RequestBody({
                url: "", httpMethod: "", headers: "", queryParams: "", body: "", postProcessJq: "", abiSignature: ""
            }),
            responseBody: IWeb2Json.ResponseBody({abiEncodedData: encoded})
        });

        proof = IWeb2Json.Proof({merkleProof: new bytes32[](0), data: response});
    }

    function _mockFdcVerification(bool willVerify) internal {
        vm.mockCall(
            FLARE_CONTRACT_REGISTRY_ADDRESS,
            abi.encodeWithSignature("getContractAddressByHash(bytes32)", keccak256(abi.encode("FdcVerification"))),
            abi.encode(fdcVerificationMock)
        );

        vm.mockCall(
            fdcVerificationMock,
            abi.encodeWithSelector(IWeb2JsonVerification.verifyWeb2Json.selector),
            abi.encode(willVerify)
        );
    }
}
