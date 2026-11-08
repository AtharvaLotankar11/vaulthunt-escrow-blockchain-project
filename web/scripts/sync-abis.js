#!/usr/bin/env node
// Copies the contract ABIs and deployed addresses from the Foundry project into the web app.
//
//   pnpm sync                         (run from the web folder)
//   node scripts/sync-abis.js --contracts ../contracts
//
// Reads : <contracts>/out/<Name>.sol/<Name>.json        (written by `forge build`)
//         <contracts>/deployments/<chainId>.json        (written by script/Deploy.s.sol)
// Writes: src/contracts/abis.json and src/contracts/addresses.json
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const webRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const argIndex = process.argv.indexOf("--contracts");
const contractsDir = path.resolve(
  argIndex > -1 ? process.argv[argIndex + 1] : path.join(webRoot, "..", "contracts"),
);

const CONTRACTS = [
  "BountyToken",
  "PlatformTreasury",
  "ReputationSBT",
  "BountyFactory",
  "BountyEscrow",
  "ReportRegistry",
  "DisputeCourt",
  "ProgramDirectory",
];

// deployment file key -> name used in the app
const ADDRESS_KEYS = {
  token: "BountyToken",
  treasury: "PlatformTreasury",
  sbt: "ReputationSBT",
  factory: "BountyFactory",
  escrowImplementation: "BountyEscrowImplementation",
  registry: "ReportRegistry",
  court: "DisputeCourt",
  directory: "ProgramDirectory",
  deployer: "Deployer",
};

function fail(message) {
  console.error(`sync-abis: ${message}`);
  process.exit(1);
}

// ---- ABIs
const abis = {};
for (const name of CONTRACTS) {
  const file = path.join(contractsDir, "out", `${name}.sol`, `${name}.json`);
  if (!fs.existsSync(file)) {
    fail(`missing ${file}\n  Run "forge build" in the contracts folder first.`);
  }
  const artifact = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!Array.isArray(artifact.abi)) fail(`no ABI found in ${file}`);
  abis[name] = artifact.abi;
}

// ---- addresses
const addresses = {};
const deploymentsDir = path.join(contractsDir, "deployments");
if (fs.existsSync(deploymentsDir)) {
  for (const entry of fs.readdirSync(deploymentsDir)) {
    if (!/^\d+\.json$/.test(entry)) continue;
    const chainId = entry.replace(".json", "");
    const json = JSON.parse(fs.readFileSync(path.join(deploymentsDir, entry), "utf8"));
    addresses[chainId] = {};
    for (const [key, appName] of Object.entries(ADDRESS_KEYS)) {
      if (json[key]) addresses[chainId][appName] = json[key];
    }
    // the block the contracts were deployed at: the app reads events from here
    addresses[chainId].DeploymentBlock = Number(json.deploymentBlock ?? 0);
  }
}
if (Object.keys(addresses).length === 0) {
  console.warn(
    "sync-abis: no deployments found. Run Deploy.s.sol first; addresses.json will be empty.",
  );
}

// ---- write
const outDir = path.join(webRoot, "src", "contracts");
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "abis.json"), JSON.stringify(abis));
fs.writeFileSync(path.join(outDir, "addresses.json"), JSON.stringify(addresses, null, 2) + "\n");

console.log(`sync-abis: ${CONTRACTS.length} ABIs written to ${path.relative(webRoot, outDir)}`);
console.log(`sync-abis: addresses for chain(s): ${Object.keys(addresses).join(", ") || "none"}`);
