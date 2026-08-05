// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Surl} from "surl-0.0.0/src/Surl.sol";

// Shared helpers for talking to Flare's FDC verifier and DA Layer servers.
// Reconstructed from Flare's official Web2Json/Payment Foundry guides.
abstract contract FdcBase is Script {
    using Surl for *;

    // NOTE: the exact shape of the verifier's prepareRequest response is not
    // publicly documented beyond "status" + "abiEncodedRequest" fields. If
    // parsing fails here, this struct's field order/types is the first
    // place to check - vm.parseJson requires fields declared in the
    // alphabetical order of the JSON keys, not the order they appear in the
    // response.
    struct AttestationResponse {
        bytes abiEncodedRequest;
        string status;
    }

    struct ParsableProof {
        bytes32 attestationType;
        bytes32[] proofs;
        bytes responseHex;
    }

    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function toUtf8HexString(string memory _string) internal pure returns (string memory) {
        string memory encodedString = toHexString(abi.encodePacked(_string));
        uint256 stringLength = bytes(encodedString).length;
        require(stringLength <= 64, "String too long");
        uint256 paddingLength = 64 - stringLength + 2;
        for (uint256 i = 0; i < paddingLength; i++) {
            encodedString = string.concat(encodedString, "0");
        }
        return encodedString;
    }

    function prepareHeaders(string memory apiKey) internal pure returns (string[] memory) {
        string[] memory headers = new string[](2);
        headers[0] = string.concat('"X-API-KEY": ', apiKey);
        headers[1] = '"Content-Type": "application/json"';
        return headers;
    }

    function prepareBody(string memory attestationType, string memory sourceId, string memory requestBody)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            '{"attestationType": "',
            attestationType,
            '", "sourceId": "',
            sourceId,
            '", "requestBody": ',
            requestBody,
            "}"
        );
    }

    function parseAttestationRequest(bytes memory data) internal returns (AttestationResponse memory) {
        string memory dataString = string(data);

        // First check if there's an error response
        try vm.parseJsonString(dataString, ".statusCode") returns (string memory) {
            string memory errorMessage = vm.parseJsonString(dataString, ".message");
            console.log("Verifier error: %s", errorMessage);
            revert(string.concat("Attestation request failed: ", errorMessage));
        } catch {
            // No error response, continue with normal parsing
        }

        string memory status = vm.parseJsonString(dataString, ".status");

        if (keccak256(bytes(status)) != keccak256(bytes("VALID"))) {
            console.log("Verifier rejected the request. Status: %s", status);
            revert(string.concat("Attestation request invalid: ", status));
        }

        bytes memory abiEncodedRequest = vm.parseJsonBytes(dataString, ".abiEncodedRequest");

        return AttestationResponse({abiEncodedRequest: abiEncodedRequest, status: status});
    }

    function writeToFile(string memory dirPath, string memory fileName, string memory content, bool overwrite)
        internal
    {
        string memory path = string.concat(dirPath, fileName, ".txt");
        if (overwrite && vm.exists(path)) {
            vm.removeFile(path);
        }
        vm.writeLine(path, content);
    }
}
