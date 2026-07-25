// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWeatherOracle} from "./interfaces/IWeatherOracle.sol";
import {IDataConnector} from "./interfaces/IDataConnector.sol";
import {ISettlementVerifier} from "./interfaces/ISettlementVerifier.sol";

/// @title WeatherVault
/// @notice Parametric weather insurance using two data sources and a TEE attestation.
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

    IWeatherOracle public immutable weatherOracle;
    IDataConnector public immutable dataConnector;
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
        uint256 indexed policyId,
        address indexed farmer,
        uint256 payout,
        uint256 weatherOracleReading,
        uint256 dataConnectorReading,
        uint8 riskTier
    );

    event PolicyExpired(uint256 indexed policyId, address indexed farmer);

    error InvalidPolicy();
    error PolicyNotFound();
    error PolicyAlreadyFinalized();
    error CoveragePeriodNotEnded();
    error ExpiryWindowNotReached();
    error DataSourcesDisagree();
    error TriggerNotMet();
    error InvalidSettlementProof();
    error InsufficientPoolBalance();
    error TransferFailed();

    constructor(
        IWeatherOracle _weatherOracle,
        IDataConnector _dataConnector,
        ISettlementVerifier _settlementVerifier
    ) {
        weatherOracle = _weatherOracle;
        dataConnector = _dataConnector;
        settlementVerifier = _settlementVerifier;
    }

    /// @notice Funds the insurance pool with test FLR for demo payouts.
    function fundPool() external payable {
        if (msg.value == 0) revert InvalidPolicy();
        emit PoolFunded(msg.sender, msg.value);
    }

    /// @notice Creates a weather insurance policy.
    /// @param regionHash Hash of a public preset region, not an exact farm location.
    /// @param parameter 0 = rainfall below threshold; 1 = temperature above threshold.
    function createPolicy(
        bytes32 regionHash,
        uint8 parameter,
        uint128 threshold,
        uint64 coverageEnd
    ) external payable returns (uint256 policyId) {
        if (
            msg.value == 0 ||
            regionHash == bytes32(0) ||
            parameter > uint8(Parameter.TemperatureCentiCelsius) ||
            threshold == 0 ||
            coverageEnd <= block.timestamp
        ) {
            revert InvalidPolicy();
        }

        policyId = nextPolicyId++;

        policies[policyId] = Policy({
            farmer: msg.sender,
            regionHash: regionHash,
            coverageEnd: coverageEnd,
            threshold: threshold,
            premium: uint128(msg.value),
            parameter: parameter,
            status: Status.Active
        });

        emit PolicyCreated(
            policyId,
            msg.sender,
            regionHash,
            coverageEnd,
            threshold,
            uint128(msg.value),
            parameter
        );
    }

    /// @notice Pays a triggered policy after both data sources agree and FCC approves.
    /// @dev Anyone may call this, so settlement does not rely on the farmer being online.
    function executePayout(
        uint256 policyId,
        uint8 riskTier,
        bytes calldata teeProof
    ) external {
        Policy storage policy = _activePolicyAfterCoverage(policyId);

        if (riskTier > 3) revert InvalidPolicy();

        uint256 oracleReading = weatherOracle.getWeatherReading(
            policy.regionHash,
            policy.parameter,
            policy.coverageEnd
        );

        uint256 verifiedReading = dataConnector.getVerifiedWeatherReading(
            policy.regionHash,
            policy.parameter,
            policy.coverageEnd
        );

        if (oracleReading != verifiedReading) revert DataSourcesDisagree();

        bool triggered = _isTriggered(
            policy.parameter,
            oracleReading,
            policy.threshold
        );

        if (!triggered) revert TriggerNotMet();

        bytes32 policyDigest = getPolicyDigest(policyId, riskTier);

        if (
            !settlementVerifier.verifySettlement(
                policyDigest,
                triggered,
                riskTier,
                teeProof
            )
        ) {
            revert InvalidSettlementProof();
        }

        // Base cover is 120% of premium; higher FCC risk tiers add 10% each.
        uint256 payout = (uint256(policy.premium) * (120 + riskTier * 10)) / 100;

        if (address(this).balance < payout) revert InsufficientPoolBalance();

        policy.status = Status.Paid;

        (bool sent, ) = policy.farmer.call{value: payout}("");
        if (!sent) revert TransferFailed();

        emit PayoutExecuted(
            policyId,
            policy.farmer,
            payout,
            oracleReading,
            verifiedReading,
            riskTier
        );
    }

    /// @notice Refunds a policy if settlement data never becomes available.
    function claimExpired(uint256 policyId) external {
        Policy storage policy = policies[policyId];

        if (policy.farmer == address(0)) revert PolicyNotFound();
        if (policy.status != Status.Active) revert PolicyAlreadyFinalized();
        if (block.timestamp < policy.coverageEnd + 7 days) {
            revert ExpiryWindowNotReached();
        }

        policy.status = Status.Expired;

        (bool sent, ) = policy.farmer.call{value: policy.premium}("");
        if (!sent) revert TransferFailed();

        emit PolicyExpired(policyId, policy.farmer);
    }

    /// @notice Produces the exact digest the TEE mock must approve.
    function getPolicyDigest(
        uint256 policyId,
        uint8 riskTier
    ) public view returns (bytes32) {
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

    function _activePolicyAfterCoverage(
        uint256 policyId
    ) private view returns (Policy storage policy) {
        policy = policies[policyId];

        if (policy.farmer == address(0)) revert PolicyNotFound();
        if (policy.status != Status.Active) revert PolicyAlreadyFinalized();
        if (block.timestamp < policy.coverageEnd) {
            revert CoveragePeriodNotEnded();
        }
    }

    function _isTriggered(
        uint8 parameter,
        uint256 reading,
        uint128 threshold
    ) private pure returns (bool) {
        if (parameter == uint8(Parameter.RainfallMm)) {
            return reading < threshold;
        }

        return reading > threshold;
    }
}