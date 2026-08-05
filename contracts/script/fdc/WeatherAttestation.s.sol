// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "forge-std/console.sol";
import {Surl} from "surl-0.0.0/src/Surl.sol";
import {FdcBase} from "./Base.s.sol";
import {ContractRegistry} from "flare-periphery-0.1.37/src/coston2/ContractRegistry.sol";
import {IFdcRequestFeeConfigurations} from "flare-periphery-0.1.37/src/coston2/IFdcRequestFeeConfigurations.sol";
import {IFdcHub} from "flare-periphery-0.1.37/src/coston2/IFdcHub.sol";
import {IFlareSystemsManager} from "flare-periphery-0.1.37/src/coston2/IFlareSystemsManager.sol";
import {IWeb2Json} from "flare-periphery-0.1.37/src/coston2/IWeb2Json.sol";

string constant attestationTypeName = "Web2Json";
string constant sourceName = "PublicWeb2";
string constant dirPath = "data/";

/// @notice Step 1: build and submit a Web2Json attestation request for a
/// location's current rainfall from OpenWeatherMap, to Flare's testnet
/// verifier. The attested result decodes on-chain into WeatherVault's
/// WeatherReading struct (region, observedAt, value).
/// @dev Edit `city`/`countryCode`/`lat`/`lon` below to match the policy's
/// region before each run. City-name (`q=`) queries were unreliable against
/// the verifier's fetch stage, so we query by coordinates instead and carry
/// the human-readable region through as a label.
contract PrepareWeatherAttestationRequest is FdcBase {
    using Surl for *;

    // Human-readable label - `city, countryName(countryCode)` must EXACTLY
    // equal the string hashed in createPolicy(), or executePayout reverts
    // with RegionMismatch. Coordinates below decide which location's weather
    // is actually attested.
    string public city = "Kaduna";
    string public countryCode = "NG";
    string public lat = "10.5222"; // Kaduna, Nigeria
    string public lon = "7.4383";

    function run() external {
        string memory apiKey = vm.envString("OPEN_WEATHER_API_KEY");

        string memory apiUrl = string.concat(
            "https://api.openweathermap.org/data/2.5/weather?lat=",
            lat,
            "&lon=",
            lon,
            "&appid=",
            apiKey,
            "&units=metric"
        );

        // Region is a fixed label (must match the policy's regionHash), the
        // timestamp comes from the API's `dt`, and rainfall is the last-hour
        // total in whole mm - defaulted to 0 when `rain` is absent (no rain),
        // then floored since the on-chain `value` is an integer.
        string memory region = string.concat(city, ", ", countryName(countryCode));
        string memory postProcessJq = string.concat(
            "{region: \\\"", region, "\\\", observedAt: .dt, value: ((.rain.\\\"1h\\\" // 0) | floor)}"
        );

        string memory abiSignature = "{\\\"components\\\":["
            "{\\\"internalType\\\":\\\"string\\\",\\\"name\\\":\\\"region\\\",\\\"type\\\":\\\"string\\\"},"
            "{\\\"internalType\\\":\\\"uint64\\\",\\\"name\\\":\\\"observedAt\\\",\\\"type\\\":\\\"uint64\\\"},"
            "{\\\"internalType\\\":\\\"uint256\\\",\\\"name\\\":\\\"value\\\",\\\"type\\\":\\\"uint256\\\"}"
            "],\\\"name\\\":\\\"DataTransportObject\\\",\\\"type\\\":\\\"tuple\\\"}";

        string memory requestBody = string.concat(
            '{"url": "',
            apiUrl,
            '","httpMethod": "GET",' '"headers": "{}",' '"queryParams": "{}",' '"body": "{}",' '"postProcessJq": "',
            postProcessJq,
            '","abiSignature": "',
            abiSignature,
            '"}'
        );

        string memory attestationType = toUtf8HexString(attestationTypeName);
        string memory sourceId = toUtf8HexString(sourceName);
        string memory verifierApiKey = vm.envString("VERIFIER_API_KEY_TESTNET");
        string[] memory headers = prepareHeaders(verifierApiKey);
        string memory body = prepareBody(attestationType, sourceId, requestBody);

        string memory baseUrl = vm.envString("VERIFIER_URL_TESTNET");
        string memory url = string.concat(baseUrl, "/verifier/web2/Web2Json/prepareRequest");
        console.log("url: %s", url);

        (, bytes memory data) = url.post(headers, body);
        AttestationResponse memory response = parseAttestationRequest(data);

        console.log("status: %s", response.status);
        console.log("abiEncodedRequest:");
        console.logBytes(response.abiEncodedRequest);

        writeToFile(dirPath, "Web2Json_abiEncodedRequest", toHexString(response.abiEncodedRequest), true);
    }

    // Minimal country-code lookup for the jq literal - extend as needed.
    function countryName(string memory code) internal pure returns (string memory) {
        bytes32 codeHash = keccak256(bytes(code));
        if (codeHash == keccak256(bytes("NG"))) return "Nigeria";
        if (codeHash == keccak256(bytes("US"))) return "USA";
        if (codeHash == keccak256(bytes("IN"))) return "India";
        if (codeHash == keccak256(bytes("GB"))) return "United Kingdom";
        return code;
    }
}

/// @notice Step 2: submit the prepared request to FdcHub on-chain and
/// record the voting round it lands in.
contract SubmitWeatherAttestationRequest is FdcBase {
    function run() external {
        string memory requestHex = vm.readLine(string.concat(dirPath, "Web2Json_abiEncodedRequest.txt"));
        bytes memory abiEncodedRequest = vm.parseBytes(requestHex);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IFdcRequestFeeConfigurations feeConfig = ContractRegistry.getFdcRequestFeeConfigurations();
        uint256 requestFee = feeConfig.getRequestFee(abiEncodedRequest);
        console.log("request fee: %s", requestFee);

        IFdcHub fdcHub = ContractRegistry.getFdcHub();
        fdcHub.requestAttestation{value: requestFee}(abiEncodedRequest);

        IFlareSystemsManager systemsManager = ContractRegistry.getFlareSystemsManager();
        uint32 roundId = systemsManager.getCurrentVotingEpochId();
        console.log("votingRoundId: %s", roundId);

        vm.stopBroadcast();

        writeToFile(dirPath, "Web2Json_votingRoundId", vm.toString(roundId), true);
    }
}

/// @notice Step 3: fetch the finalized proof from the DA Layer once the
/// voting round has closed (wait ~90-180 seconds after step 2 before running).
contract RetrieveWeatherProof is FdcBase {
    using Surl for *;

    function run() external {
        string memory daLayerUrl = vm.envString("COSTON2_DA_LAYER_URL");
        string memory apiKey = vm.envString("X_API_KEY");

        string memory requestBytes = vm.readLine(string.concat(dirPath, "Web2Json_abiEncodedRequest.txt"));
        string memory votingRoundId = vm.readLine(string.concat(dirPath, "Web2Json_votingRoundId.txt"));

        string[] memory headers = prepareHeaders(apiKey);
        string memory body = string.concat('{"votingRoundId":', votingRoundId, ',"requestBytes":"', requestBytes, '"}');

        string memory url = string.concat(daLayerUrl, "api/v1/fdc/proof-by-request-round-raw");
        console.log("url: %s", url);

        (, bytes memory data) = url.post(headers, body);
        bytes memory dataJson = vm.parseJson(string(data));
        ParsableProof memory proof = abi.decode(dataJson, (ParsableProof));

        IWeb2Json.Response memory proofResponse = abi.decode(proof.responseHex, (IWeb2Json.Response));

        IWeb2Json.Proof memory fullProof = IWeb2Json.Proof({merkleProof: proof.proofs, data: proofResponse});

        writeToFile(dirPath, "Web2Json_proof", toHexString(abi.encode(fullProof)), true);
        console.log("Proof saved to data/Web2Json_proof.txt");
    }
}
