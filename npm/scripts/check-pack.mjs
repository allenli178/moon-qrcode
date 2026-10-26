import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = execFileSync(
  "npm",
  ["pack", "--dry-run", "--ignore-scripts", "--json"],
  {
    cwd: packageRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  },
);
const [info] = JSON.parse(output);
const files = new Set(info.files.map((file) => file.path));
const required = [
  "index.js",
  "index.d.ts",
  "dist/moonbit.js",
  "README.md",
  "package.json",
];
const missing = required.filter((path) => !files.has(path));
if (missing.length > 0) {
  throw new Error(`npm package is missing: ${missing.join(", ")}`);
}
console.log(
  `npm pack: ${files.size} files, ${info.size} bytes, required entries present`,
);
