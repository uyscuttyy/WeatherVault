import { useState } from "react";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

type PolicyStatus = "Active" | "Paid";

type Policy = {
  id: number;
  region: string;
  threshold: number;
  premium: number;
  coverageEnd: string;
  status: PolicyStatus;
};

const rainfallHistory = [
  { day: "Day 1", rainfall: 68 },
  { day: "Day 2", rainfall: 61 },
  { day: "Day 3", rainfall: 57 },
  { day: "Day 4", rainfall: 53 },
  { day: "Day 5", rainfall: 47 },
  { day: "Day 6", rainfall: 44 },
  { day: "Today", rainfall: 42 },
];

const regions = ["Kaduna, Nigeria", "Kano, Nigeria", "Plateau, Nigeria"];

export default function App() {
  const [region, setRegion] = useState(regions[0]);
  const [threshold, setThreshold] = useState(50);
  const [premium, setPremium] = useState(1);
  const [coverageEnd, setCoverageEnd] = useState("2026-08-21");
  const [policies, setPolicies] = useState<Policy[]>([]);
  const [isCreating, setIsCreating] = useState(false);

  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  const injectedConnector = connectors[0];

  const shortAddress = address
    ? `${address.slice(0, 6)}…${address.slice(-4)}`
    : "";

  const currentRainfall = 42;
  const droughtTriggered = currentRainfall < threshold;

  function createDemoPolicy(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsCreating(true);

    window.setTimeout(() => {
      setPolicies((currentPolicies) => [
        {
          id: currentPolicies.length + 1,
          region,
          threshold,
          premium,
          coverageEnd,
          status: "Active",
        },
        ...currentPolicies,
      ]);

      setIsCreating(false);
    }, 500);
  }

  function settleDemoPolicy(policyId: number) {
    setPolicies((currentPolicies) =>
      currentPolicies.map((policy) =>
        policy.id === policyId && currentRainfall < policy.threshold
          ? { ...policy, status: "Paid" }
          : policy,
      ),
    );
  }

  return (
    <main className="min-h-screen bg-slate-950 text-slate-100">
      <header className="mx-auto flex max-w-7xl items-center justify-between px-6 py-6">
        <a className="flex items-center gap-3" href="#">
          <span className="grid h-10 w-10 place-items-center rounded-xl bg-cyan-400 text-lg font-black text-slate-950">
            W
          </span>
          <span>
            <span className="block text-lg font-bold tracking-tight">
              WeatherVault
            </span>
            <span className="block text-xs text-slate-400">
              Parametric protection on Flare
            </span>
          </span>
        </a>
        <div className="flex items-center gap-3">
          <span className="rounded-full border border-amber-400/30 bg-amber-400/10 px-3 py-1 text-xs font-semibold text-amber-200">
            Demo Mode · Coston2
          </span>

          {isConnected ? (
            <button
              className="rounded-xl border border-cyan-400/40 px-3 py-2 text-sm font-bold text-cyan-300 transition hover:bg-cyan-400/10"
              onClick={() => disconnect()}
              type="button"
            >
              {shortAddress}
            </button>
          ) : (
            <button
              className="rounded-xl bg-cyan-400 px-3 py-2 text-sm font-bold text-slate-950 transition hover:bg-cyan-300 disabled:opacity-60"
              disabled={!injectedConnector || isPending}
              onClick={() => {
                if (injectedConnector) {
                  connect({ connector: injectedConnector });
                }
              }}
              type="button"
            >
              {isPending ? "Connecting..." : "Connect wallet"}
            </button>
          )}
        </div>
      </header>

      <section className="mx-auto grid max-w-7xl gap-10 px-6 pb-16 pt-12 lg:grid-cols-[1.2fr_0.8fr] lg:items-center">
        <div>
          <p className="mb-4 text-sm font-bold uppercase tracking-[0.18em] text-cyan-300">
            Weather-triggered crop cover
          </p>

          <h1 className="max-w-3xl text-5xl font-black tracking-tight text-white sm:text-6xl">
            When the weather fails, your payout does not.
          </h1>

          <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-400">
            WeatherVault automatically settles crop-insurance policies when
            verified weather thresholds are met. No paperwork. No manual
            claims.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <a
              className="rounded-xl bg-cyan-400 px-5 py-3 font-bold text-slate-950 transition hover:bg-cyan-300"
              href="#create-policy"
            >
              Create a policy
            </a>
            <a
              className="rounded-xl border border-slate-700 px-5 py-3 font-semibold text-slate-200 transition hover:border-slate-500"
              href="#how-it-works"
            >
              How it works
            </a>
          </div>

          <div className="mt-10 flex flex-wrap gap-6 text-sm text-slate-400">
            <span>FTSOv2-style weather feed</span>
            <span>FDC-style verification</span>
            <span>FCC-style private settlement</span>
          </div>
        </div>

        <div className="rounded-3xl border border-cyan-400/20 bg-slate-900/80 p-6 shadow-2xl shadow-cyan-950/30">
          <p className="text-sm font-medium text-slate-400">
            Kaduna rainfall · Current settled reading
          </p>

          <div className="mt-3 flex items-end justify-between">
            <p className="text-6xl font-black text-cyan-300">
              {currentRainfall}
              <span className="ml-2 text-2xl text-slate-400">mm</span>
            </p>

            <span
              className={`rounded-full px-3 py-1 text-sm font-bold ${droughtTriggered
                ? "bg-emerald-400/15 text-emerald-300"
                : "bg-slate-800 text-slate-300"
                }`}
            >
              {droughtTriggered ? "Payout condition met" : "No trigger"}
            </span>
          </div>

          <div className="mt-6 h-52">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={rainfallHistory}>
                <defs>
                  <linearGradient id="rainfallGradient" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="0%" stopColor="#22d3ee" stopOpacity={0.5} />
                    <stop offset="100%" stopColor="#22d3ee" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="#1e293b" vertical={false} />
                <XAxis dataKey="day" stroke="#64748b" tickLine={false} axisLine={false} />
                <YAxis stroke="#64748b" tickLine={false} axisLine={false} />
                <Tooltip
                  contentStyle={{
                    background: "#0f172a",
                    border: "1px solid #334155",
                    borderRadius: "12px",
                  }}
                />
                <ReferenceLine
                  y={threshold}
                  stroke="#fbbf24"
                  strokeDasharray="5 5"
                  label={{ value: "Threshold", fill: "#fbbf24", position: "insideTopRight" }}
                />
                <Area
                  type="monotone"
                  dataKey="rainfall"
                  stroke="#22d3ee"
                  strokeWidth={3}
                  fill="url(#rainfallGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
            <div className="rounded-xl bg-slate-800/80 p-3">
              <p className="text-slate-400">FTSOv2 mock</p>
              <p className="mt-1 font-bold text-white">42 mm</p>
            </div>
            <div className="rounded-xl bg-slate-800/80 p-3">
              <p className="text-slate-400">FDC mock</p>
              <p className="mt-1 font-bold text-white">42 mm · Verified</p>
            </div>
          </div>
        </div>
      </section>

      <section
        id="create-policy"
        className="mx-auto grid max-w-7xl gap-6 px-6 py-12 lg:grid-cols-[0.9fr_1.1fr]"
      >
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-cyan-300">
            Protection in minutes
          </p>
          <h2 className="mt-3 text-3xl font-black text-white">
            Create your weather policy
          </h2>
          <p className="mt-4 max-w-md leading-7 text-slate-400">
            Choose a public regional preset. Exact farm coordinates and
            complete policy terms are intended to remain private through
            Confidential Compute.
          </p>
        </div>

        <form
          className="rounded-2xl border border-slate-800 bg-slate-900 p-6"
          onSubmit={createDemoPolicy}
        >
          <div className="grid gap-5 sm:grid-cols-2">
            <label className="text-sm font-semibold text-slate-300">
              Region
              <select
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-white outline-none focus:border-cyan-400"
                value={region}
                onChange={(event) => setRegion(event.target.value)}
              >
                {regions.map((regionOption) => (
                  <option key={regionOption}>{regionOption}</option>
                ))}
              </select>
            </label>

            <label className="text-sm font-semibold text-slate-300">
              Weather parameter
              <select
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-white outline-none focus:border-cyan-400"
                defaultValue="rainfall"
              >
                <option value="rainfall">Rainfall (mm)</option>
                <option value="temperature">Temperature (°C)</option>
              </select>
            </label>

            <label className="text-sm font-semibold text-slate-300">
              Drought threshold (mm)
              <input
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-white outline-none focus:border-cyan-400"
                min="1"
                type="number"
                value={threshold}
                onChange={(event) => setThreshold(Number(event.target.value))}
              />
            </label>

            <label className="text-sm font-semibold text-slate-300">
              Premium (test FLR)
              <input
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-white outline-none focus:border-cyan-400"
                min="0.1"
                step="0.1"
                type="number"
                value={premium}
                onChange={(event) => setPremium(Number(event.target.value))}
              />
            </label>

            <label className="text-sm font-semibold text-slate-300 sm:col-span-2">
              Coverage end date
              <input
                className="mt-2 w-full rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-white outline-none focus:border-cyan-400"
                type="date"
                value={coverageEnd}
                onChange={(event) => setCoverageEnd(event.target.value)}
              />
            </label>
          </div>

          <button
            className="mt-6 w-full rounded-xl bg-cyan-400 px-5 py-3 font-bold text-slate-950 transition hover:bg-cyan-300 disabled:cursor-not-allowed disabled:opacity-60"
            disabled={isCreating}
            type="submit"
          >
            {isCreating ? "Creating demo policy..." : "Create policy"}
          </button>
        </form>
      </section>

      <section className="mx-auto max-w-7xl px-6 py-12">
        <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-sm font-bold uppercase tracking-[0.18em] text-cyan-300">
                Portfolio
              </p>
              <h2 className="mt-2 text-2xl font-black text-white">My policies</h2>
            </div>
            <span className="text-sm text-slate-400">
              Wallet connection comes next
            </span>
          </div>

          {policies.length === 0 ? (
            <p className="mt-8 rounded-xl border border-dashed border-slate-700 p-6 text-slate-400">
              No policies created in this browser session. Use the form above
              to create a demo policy.
            </p>
          ) : (
            <div className="mt-6 overflow-x-auto">
              <table className="w-full min-w-180 text-left text-sm">
                <thead className="border-b border-slate-800 text-slate-400">
                  <tr>
                    <th className="px-3 py-3">Policy</th>
                    <th className="px-3 py-3">Region</th>
                    <th className="px-3 py-3">Trigger</th>
                    <th className="px-3 py-3">Premium</th>
                    <th className="px-3 py-3">Status</th>
                    <th className="px-3 py-3" />
                  </tr>
                </thead>
                <tbody>
                  {policies.map((policy) => (
                    <tr key={policy.id} className="border-b border-slate-800/70">
                      <td className="px-3 py-4 font-semibold">#{policy.id}</td>
                      <td className="px-3 py-4 text-slate-300">{policy.region}</td>
                      <td className="px-3 py-4 text-slate-300">
                        Rainfall &lt; {policy.threshold} mm
                      </td>
                      <td className="px-3 py-4 text-slate-300">
                        {policy.premium} FLR
                      </td>
                      <td className="px-3 py-4">
                        <span
                          className={
                            policy.status === "Paid"
                              ? "font-semibold text-emerald-300"
                              : "font-semibold text-amber-200"
                          }
                        >
                          {policy.status}
                        </span>
                      </td>
                      <td className="px-3 py-4 text-right">
                        <button
                          className="rounded-lg border border-cyan-400/40 px-3 py-2 text-xs font-bold text-cyan-300 transition hover:bg-cyan-400/10 disabled:cursor-not-allowed disabled:opacity-40"
                          disabled={policy.status === "Paid"}
                          onClick={() => settleDemoPolicy(policy.id)}
                          type="button"
                        >
                          Verify & payout
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </section>

      <section id="how-it-works" className="mx-auto max-w-7xl px-6 py-16">
        <p className="text-sm font-bold uppercase tracking-[0.18em] text-cyan-300">
          Automatic by design
        </p>
        <h2 className="mt-3 text-3xl font-black text-white">How it works</h2>

        <div className="mt-8 grid gap-4 md:grid-cols-4">
          {[
            ["01", "Create a policy", "Choose a region, threshold, period, and premium."],
            ["02", "Weather period closes", "The policy becomes eligible for settlement."],
            ["03", "Data sources agree", "FTSOv2 and FDC verify the same reading."],
            ["04", "Payout executes", "FCC validation authorizes automatic settlement."],
          ].map(([number, title, description]) => (
            <article
              key={number}
              className="rounded-2xl border border-slate-800 bg-slate-900 p-5"
            >
              <span className="text-sm font-black text-cyan-300">{number}</span>
              <h3 className="mt-5 text-lg font-bold text-white">{title}</h3>
              <p className="mt-2 text-sm leading-6 text-slate-400">{description}</p>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}