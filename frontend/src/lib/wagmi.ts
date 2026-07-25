import { defineChain } from "viem";
import { http, createConfig } from "wagmi";
import { injected } from "wagmi/connectors";

export const coston2 = defineChain({
    id: 114,
    name: "Flare Testnet Coston2",
    nativeCurrency: {
        name: "C2FLR",
        symbol: "C2FLR",
        decimals: 18,
    },
    rpcUrls: {
        default: {
            http: ["https://coston2-api.flare.network/ext/C/rpc"],
        },
    },
    blockExplorers: {
        default: {
            name: "Coston2 Explorer",
            url: "https://coston2-explorer.flare.network",
        },
    },
    testnet: true,
});

export const wagmiConfig = createConfig({
    chains: [coston2],
    connectors: [injected()],
    transports: {
        [coston2.id]: http(),
    },
});