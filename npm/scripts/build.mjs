import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(packageRoot, "..");
const moon = process.env.MOON_BIN ?? "moon";

execFileSync(moon, ["build", "js", "--target", "js", "--release"], {
  cwd: repositoryRoot,
  stdio: "inherit",
});

const built = resolve(repositoryRoot, "_build/js/release/build/js/js.js");
if (!existsSync(built)) {
  throw new Error(`MoonBit JS build did not produce ${built}`);
}

const dist = resolve(packageRoot, "dist");
mkdirSync(dist, { recursive: true });
copyFileSync(built, resolve(dist, "moonbit.js"));
console.log(`copied ${built} -> ${resolve(dist, "moonbit.js")}`);
