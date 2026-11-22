import type { OnboardingInput } from "@rwa-vault/types";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import type { EIP1193Provider, Hex } from "viem";
import { connect, type OnboardingChain } from "../onboarding/chain.js";
import { wasmVerify } from "../onboarding/clause1.js";
import { loadCustodianKey } from "../onboarding/custodian.js";
import { deploymentFor } from "../onboarding/deployments.js";
import { AdmitStep } from "./AdmitStep.js";
import { AssetStep } from "./AssetStep.js";
import { AttestationStep, type Verified } from "./AttestationStep.js";
import { MintStep } from "./MintStep.js";
import { Problem } from "./common.js";

const queryClient = new QueryClient();

declare global {
  interface Window {
    ethereum?: EIP1193Provider;
  }
}

/** The four-step onboarding wizard, once connected. */
export function Wizard({ chain }: { chain: OnboardingChain }) {
  const [input, setInput] = useState<OnboardingInput>();
  const [verified, setVerified] = useState<Verified>();
  const [atMint, setAtMint] = useState(false);
  if (!input) return <AssetStep chain={chain} onNext={setInput} />;
  if (!verified) {
    return (
      <AttestationStep
        chain={chain}
        input={input}
        loadKey={loadCustodianKey}
        loadVerify={wasmVerify}
        onNext={setVerified}
      />
    );
  }
  if (!atMint)
    return (
      <AdmitStep chain={chain} input={input} verified={verified} onNext={() => setAtMint(true)} />
    );
  return <MintStep chain={chain} input={input} />;
}

function Connect({ onConnected }: { onConnected: (c: OnboardingChain) => void }) {
  const [rpcUrl, setRpcUrl] = useState("http://127.0.0.1:8545");
  const [key, setKey] = useState("");
  const [error, setError] = useState<string>();
  const go = async (f: () => Promise<OnboardingChain>) => {
    setError(undefined);
    try {
      onConnected(await f());
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };
  return (
    <section>
      <h2>Connect the agent key</h2>
      <button
        type="button"
        disabled={!window.ethereum}
        onClick={() =>
          go(() => connect({ kind: "injected", provider: window.ethereum! }, deploymentFor))
        }
      >
        Browser wallet
      </button>
      <fieldset>
        <legend>Local anvil only</legend>
        <label>
          RPC URL <input value={rpcUrl} onChange={(e) => setRpcUrl(e.target.value)} />
        </label>
        <label>
          Anvil dev key (agent){" "}
          <input type="password" value={key} onChange={(e) => setKey(e.target.value)} />
        </label>
        <button
          type="button"
          disabled={!/^0x[0-9a-fA-F]{64}$/.test(key)}
          onClick={() =>
            go(() =>
              connect({ kind: "anvil-dev-key", rpcUrl, privateKey: key as Hex }, deploymentFor),
            )
          }
        >
          Use anvil dev key
        </button>
      </fieldset>
      {error && <Problem>{error}</Problem>}
    </section>
  );
}

export function App() {
  const [chain, setChain] = useState<OnboardingChain>();
  return (
    <QueryClientProvider client={queryClient}>
      <main>
        <h1>Onboard an asset lot</h1>
        {chain ? <Wizard chain={chain} /> : <Connect onConnected={setChain} />}
      </main>
    </QueryClientProvider>
  );
}
