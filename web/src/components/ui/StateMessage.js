import { Chip } from "@/components/ui/Chip";

export function StateMessage({ tone, title, children }) {
  return (
    <div className="gradient-panel max-w-2xl">
      <Chip size="sm" tone={tone}>{title}</Chip>
      <div className="mt-4 text-muted">{children}</div>
    </div>
  );
}

export const NoDeployment = ({ chainId }) => (
  <StateMessage tone="alert" title="No deployment">
    No contracts are synced for chain {chainId}. Deploy them, then run <code>pnpm sync</code> in the web folder.
  </StateMessage>
);

export const ChainDown = () => (
  <StateMessage tone="alert" title="Chain not reachable">
    Could not read the chain. Start <code>anvil</code>, then run the Deploy and Seed scripts.
  </StateMessage>
);
