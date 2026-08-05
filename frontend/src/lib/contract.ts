// Deployed WeatherVault on Flare Coston2 (chain id 114).
// Redeployed to integrate real FDC weather verification - do NOT change
// without redeploying first.
export const weatherVaultAddress =
  "0xe2879c047C3d319706d22303cCda836D1BF10AD5" as const;

export const settlementVerifierAddress =
  "0x560d65A09793706944cD62B31d46ae6D684ae811" as const;

// Flare Testnet Coston2 chain id - used to force MetaMask onto the right
// network before sending any transaction.
export const coston2ChainId = 114;

// Hand-written minimal ABI: only the pieces the frontend actually calls/reads.
// Kept in sync with contracts/src/WeatherVault.sol.
export const weatherVaultAbi = [
  {
    type: "function",
    name: "createPolicy",
    stateMutability: "payable",
    inputs: [
      { name: "regionHash", type: "bytes32" },
      { name: "parameter", type: "uint8" },
      { name: "threshold", type: "uint128" },
      { name: "coverageEnd", type: "uint64" },
    ],
    outputs: [{ name: "policyId", type: "uint256" }],
  },
  {
    type: "function",
    name: "executePayout",
    stateMutability: "nonpayable",
    inputs: [
      { name: "policyId", type: "uint256" },
      { name: "riskTier", type: "uint8" },
      {
        name: "weatherProof",
        type: "tuple",
        components: [
          { name: "merkleProof", type: "bytes32[]" },
          {
            name: "data",
            type: "tuple",
            components: [
              { name: "attestationType", type: "bytes32" },
              { name: "sourceId", type: "bytes32" },
              { name: "votingRound", type: "uint64" },
              { name: "lowestUsedTimestamp", type: "uint64" },
              {
                name: "requestBody",
                type: "tuple",
                components: [
                  { name: "url", type: "string" },
                  { name: "httpMethod", type: "string" },
                  { name: "headers", type: "string" },
                  { name: "queryParams", type: "string" },
                  { name: "body", type: "string" },
                  { name: "postProcessJq", type: "string" },
                  { name: "abiSignature", type: "string" },
                ],
              },
              {
                name: "responseBody",
                type: "tuple",
                components: [{ name: "abiEncodedData", type: "bytes" }],
              },
            ],
          },
        ],
      },
      { name: "teeProof", type: "bytes" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "claimExpired",
    stateMutability: "nonpayable",
    inputs: [{ name: "policyId", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "fundPool",
    stateMutability: "payable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "nextPolicyId",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "policies",
    stateMutability: "view",
    inputs: [{ name: "policyId", type: "uint256" }],
    outputs: [
      { name: "farmer", type: "address" },
      { name: "regionHash", type: "bytes32" },
      { name: "coverageEnd", type: "uint64" },
      { name: "threshold", type: "uint128" },
      { name: "premium", type: "uint128" },
      { name: "parameter", type: "uint8" },
      { name: "status", type: "uint8" },
    ],
  },
  {
    type: "function",
    name: "getPolicyDigest",
    stateMutability: "view",
    inputs: [
      { name: "policyId", type: "uint256" },
      { name: "riskTier", type: "uint8" },
    ],
    outputs: [{ type: "bytes32" }],
  },
  {
    type: "event",
    name: "PolicyCreated",
    inputs: [
      { name: "policyId", type: "uint256", indexed: true },
      { name: "farmer", type: "address", indexed: true },
      { name: "regionHash", type: "bytes32", indexed: true },
      { name: "coverageEnd", type: "uint64", indexed: false },
      { name: "threshold", type: "uint128", indexed: false },
      { name: "premium", type: "uint128", indexed: false },
      { name: "parameter", type: "uint8", indexed: false },
    ],
  },
  {
    type: "event",
    name: "PayoutExecuted",
    inputs: [
      { name: "policyId", type: "uint256", indexed: true },
      { name: "farmer", type: "address", indexed: true },
      { name: "payout", type: "uint256", indexed: false },
      { name: "verifiedReading", type: "uint256", indexed: false },
      { name: "riskTier", type: "uint8", indexed: false },
    ],
  },
] as const;

export const coston2ExplorerUrl = "https://coston2-explorer.flare.network";

export function explorerTxUrl(hash: string) {
  return `${coston2ExplorerUrl}/tx/${hash}`;
}