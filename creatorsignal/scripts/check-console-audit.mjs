import { spawnSync } from "node:child_process";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const webAppDir = resolve(scriptDir, "../console/web-app");
const sourceDir = join(webAppDir, "src");

const allowedHighAdvisories = new Map([
  [
    "GHSA-qwww-vcr4-c8h2",
    "The console uses BrowserRouter declarative mode and contains no React Server Components or RSC action handlers.",
  ],
]);

function sourceFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? sourceFiles(path) : [path];
  });
}

const source = sourceFiles(sourceDir)
  .filter((path) => /\.[cm]?[jt]sx?$/.test(path))
  .map((path) => readFileSync(path, "utf8"))
  .join("\n");

if (!source.includes("BrowserRouter")) {
  throw new Error("The React Router reachability exception requires BrowserRouter declarative mode.");
}

const rscMarkers = [
  "react-server-dom",
  "RSCRouter",
  "createFromFetch",
  "createFromReadableStream",
  "unstable_createCallServer",
];
for (const marker of rscMarkers) {
  if (source.includes(marker)) {
    throw new Error(`React Server Component marker ${marker} invalidates the audit exception.`);
  }
}

const yarnCommand = process.platform === "win32" ? process.env.ComSpec : "yarn";
const yarnArguments =
  process.platform === "win32"
    ? ["/d", "/s", "/c", "yarn audit --json"]
    : ["audit", "--json"];
const audit = spawnSync(yarnCommand, yarnArguments, {
  cwd: webAppDir,
  encoding: "utf8",
});
if (audit.error) {
  throw audit.error;
}

const advisories = [];
let summary;
for (const line of `${audit.stdout}\n${audit.stderr}`.split(/\r?\n/)) {
  if (!line.startsWith("{")) continue;
  try {
    const record = JSON.parse(line);
    if (record.type === "auditAdvisory") advisories.push(record.data.advisory);
    if (record.type === "auditSummary") summary = record.data.vulnerabilities;
  } catch {
    // Yarn may print non-JSON warnings even in JSON mode.
  }
}

if (!summary) {
  throw new Error("Yarn audit did not return a vulnerability summary.");
}

const blocking = new Map();
for (const advisory of advisories) {
  if (!new Set(["critical", "high"]).has(advisory.severity)) continue;
  const id = advisory.github_advisory_id;
  if (allowedHighAdvisories.has(id)) {
    console.log(`Allowed ${id}: ${allowedHighAdvisories.get(id)}`);
    continue;
  }
  blocking.set(id, `${advisory.severity} ${advisory.module_name}: ${advisory.title}`);
}

console.log(`Full console audit summary: ${JSON.stringify(summary)}`);
if (blocking.size > 0) {
  for (const [id, description] of blocking) console.error(`${id} ${description}`);
  process.exit(1);
}
