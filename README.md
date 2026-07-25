
# WeatherVault

WeatherVault is a parametric crop-insurance dApp built for Flare Coston2.

Farmers create policies based on measurable weather conditions such as rainfall or temperature. When the selected threshold is met, the policy settles automatically—no manual claim is required.

## Core demo flow

1. Farmer creates a policy and pays a test-FLR premium.
2. The coverage period ends.
3. Mock FTSOv2 weather data and mock FDC verification agree on a reading.
4. A mock Confidential Compute settlement attestation validates the result.
5. The smart contract automatically pays the farmer if the trigger condition is met.

## Project folders

- `contracts/` — Foundry smart contracts and tests
- `frontend/` — React, Tailwind, wagmi/viem dashboard
- `backend/` — mock Confidential Compute settlement API
- `docs/` — architecture notes, deployment steps, and demo script

> Demo Mode: Coston2. Weather data, FDC verification, and Confidential Compute are mocked for the hackathon prototype.