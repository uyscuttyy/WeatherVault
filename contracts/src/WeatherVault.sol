// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISettlementVerifier} from "./interfaces/ISettlementVerifier.sol";
import {IWeb2Json} from "flare-periphery-0.1.37/src/coston2/IWeb2Json.sol";
import {ContractRegistry} from "flare-periphery-0.1.37/src/coston2/ContractRegistry.sol";

/// @title WeatherVault
/// @notice Parametric weather insurance settled against a real Flare Data
/// Connector (FDC) Web2Json attestation of external weather data, with
/// premiums and payouts denominated in FXRP, plus a confidential-compute-
/// style settlement approval.
/// @dev Exact farm details remain off-chain; only a region hash is stored on-chain.
contract WeatherVault {
    enum Parameter {
        RainfallMm,
        TemperatureCentiCelsius
    }

    enum Status {
        Active,
        Paid,
        Expired
    }

    struct Policy {
        address farmer;
        bytes32 regionHash;
        uint64 coverageEnd;
        uint128 threshold;
        uint128 premium;
        uint8 parameter;
        Status status;
    }

    /// @notice Shape of the data we ask FDC's Web2Json attestors to return.
    /// @dev Must exactly match the `abiSignature` used when the attestation
    /// request was submitted off-chain, or decoding will revert or corrupt.
    struct WeatherReading {
        string region;
        uint64 observedAt;
        uint256 value;
    }

    /// @notice FXRP on Coston2 - a real FAsset representing XRP, 6 decimals.
    /// @dev Looked up once at deploy time via ContractRegistry, never hardcoded
    /// in advance, since the FAsset's underlying address can change.
    IERC20 public immutable fxrp;

    ISettlementVerifier public immutable settlementVerifier;

    uint256 public nextPolicyId;

    mapping(uint256 => Policy) public policies;

    event PolicyCreated(
        uint256 indexed policyId,
        address indexed farmer,
        bytes32 indexed regionHash,
        uint64 coverageEnd,
        uint128 threshold,
        uint128 premium,
        uint8 parameter
    );

    event PoolFunded(address indexed funder, uint256 amount);

    event PayoutExecuted(
        uint256 indexed policyId, address indexed farmer, uint256 payout, uint256 verifiedReading, uint8 riskTier
    );

    event PolicyExpired(uint256 indexed policyId, address indexed farmer);

    error InvalidPolicy();
    error PolicyNotFound();
    error PolicyAlreadyFinalized();
    error CoveragePeriodNotEnded();
    error ExpiryWindowNotReached();
    error InvalidWeatherProof();
    error RegionMismatch();
    error ReadingNotFreshEnough();
    error TriggerNotMet();
    error InvalidSettlementProof();
    error InsufficientPoolBalance();
    error TransferFailed();

    constructor(IERC20 _fxrp, ISettlementVerifier _settlementVerifier) {
        fxrp = _fxrp;
        settlementVerifier = _settlementVerifier;
    }

    /// @notice Funds the insurance pool with FXRP for demo payouts.
    /// @dev Caller must have approved this contract for at least `amount` first.
    function fundPool(uint256 amount) external {
        if (amount == 0) revert InvalidPolicy();

        bool sent = fxrp.transferFrom(msg.sender, address(this), amount);
        if (!sent) revert TransferFailed();

        emit PoolFunded(msg.sender, amount);
    }

    /// @notice Creates a weather insurance policy, paid in FXRP.
    /// @dev Caller must have approved this contract for at least `premium` first.
    /// @param regionHash keccak256 of the public region name string, not an exact farm location.
    /// @param parameter 0 = rainfall below threshold; 1 = temperature above threshold.
    function createPolicy(bytes32 regionHash, uint8 parameter, uint128 threshold, uint64 coverageEnd, uint128 premium)
        external
        returns (uint256 policyId)
    {
        if (
            premium == 0 || regionHash == bytes32(0) || parameter > uint8(Parameter.TemperatureCentiCelsius)
                || threshold == 0 || coverageEnd <= block.timestamp
        ) {
            revert InvalidPolicy();
        }

        bool sent = fxrp.transferFrom(msg.sender, address(this), premium);
        if (!sent) revert TransferFailed();

        policyId = nextPolicyId++;

        policies[policyId] = Policy({
            farmer: msg.sender,
            regionHash: regionHash,
            coverageEnd: coverageEnd,
            threshold: threshold,
            premium: premium,
            parameter: parameter,
            status: Status.Active
        });

        emit PolicyCreated(policyId, msg.sender, regionHash, coverageEnd, threshold, premium, parameter);
    }

    /// @notice Pays a triggered policy once a real FDC-verified weather
    /// reading confirms the threshold was breached, and the confidential
    /// settlement layer approves. Payout is sent in FXRP.
    /// @dev Anyone may call this, so settlement does not rely on the farmer being online.
    /// @param weatherProof Real Web2Json attestation proof from Flare's FDC.
    /// @param teeProof Confidential-compute settlement approval (still mocked - Tier 3).
    function executePayout(
        uint256 policyId,
        uint8 riskTier,
        IWeb2Json.Proof calldata weatherProof,
        bytes calldata teeProof
    ) external {
        Policy storage policy = _activePolicyAfterCoverage(policyId);

        if (riskTier > 3) revert InvalidPolicy();

        bool proven = ContractRegistry.getFdcVerification().verifyWeb2Json(weatherProof);
        if (!proven) revert InvalidWeatherProof();

        WeatherReading memory reading = abi.decode(weatherProof.data.responseBody.abiEncodedData, (WeatherReading));

        if (keccak256(bytes(reading.region)) != policy.regionHash) {
            revert RegionMismatch();
        }

        if (reading.observedAt < policy.coverageEnd) {
            revert ReadingNotFreshEnough();
        }

        bool triggered = _isTriggered(policy.parameter, reading.value, policy.threshold);

        if (!triggered) revert TriggerNotMet();

        bytes32 policyDigest = getPolicyDigest(policyId, riskTier);

        if (!settlementVerifier.verifySettlement(policyDigest, triggered, riskTier, teeProof)) {
            revert InvalidSettlementProof();
        }

        // Base cover is 120% of premium; higher FCC risk tiers add 10% each.
        uint256 payout = (uint256(policy.premium) * (120 + riskTier * 10)) / 100;

        if (fxrp.balanceOf(address(this)) < payout) revert InsufficientPoolBalance();

        policy.status = Status.Paid;

        bool sent = fxrp.transfer(policy.farmer, payout);
        if (!sent) revert TransferFailed();

        emit PayoutExecuted(policyId, policy.farmer, payout, reading.value, riskTier);
    }

    /// @notice Refunds a policy in FXRP if settlement data never becomes available.
    function claimExpired(uint256 policyId) external {
        Policy storage policy = policies[policyId];

        if (policy.farmer == address(0)) revert PolicyNotFound();
        if (policy.status != Status.Active) revert PolicyAlreadyFinalized();
        if (block.timestamp < policy.coverageEnd + 7 days) {
            revert ExpiryWindowNotReached();
        }

        policy.status = Status.Expired;

        bool sent = fxrp.transfer(policy.farmer, policy.premium);
        if (!sent) revert TransferFailed();

        emit PolicyExpired(policyId, policy.farmer);
    }

    /// @notice Produces the exact digest the TEE mock must approve.
    function getPolicyDigest(uint256 policyId, uint8 riskTier) public view returns (bytes32) {
        Policy memory policy = policies[policyId];

        if (policy.farmer == address(0)) revert PolicyNotFound();

        return keccak256(
            abi.encode(
                block.chainid,
                address(this),
                policyId,
                policy.farmer,
                policy.regionHash,
                policy.coverageEnd,
                policy.threshold,
                policy.premium,
                policy.parameter,
                riskTier
            )
        );
    }

    function _activePolicyAfterCoverage(uint256 policyId) private view returns (Policy storage policy) {
        policy = policies[policyId];

        if (policy.farmer == address(0)) revert PolicyNotFound();
        if (policy.status != Status.Active) revert PolicyAlreadyFinalized();
        if (block.timestamp < policy.coverageEnd) {
            revert CoveragePeriodNotEnded();
        }
    }

    function _isTriggered(uint8 parameter, uint256 reading, uint128 threshold) private pure returns (bool) {
        if (parameter == uint8(Parameter.RainfallMm)) {
            return reading < threshold;
        }

        return reading > threshold;
    }
}
