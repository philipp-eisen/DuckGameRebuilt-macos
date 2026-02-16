#!/usr/bin/env bun
/**
 * sign-macos.ts -- Code-sign the DuckGameRebuilt .app bundle with a Developer ID
 * identity using hardened runtime. Signs all files in parallel for speed.
 *
 * Usage:
 *   bun scripts/sign-macos.ts --identity "Developer ID Application: Name (TEAM_ID)"
 */
import { $ } from "bun";
import { resolve, basename, relative } from "path";
import { parseArgs } from "util";

const ROOT_DIR = resolve(import.meta.dir, "..");
const DIST_DIR = resolve(ROOT_DIR, "dist/macos");
const DEFAULT_ENTITLEMENTS = resolve(ROOT_DIR, "scripts/DuckGameRebuilt.entitlements");

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    identity: { type: "string" },
    "app-name": { type: "string", default: "DuckGameRebuilt" },
    entitlements: { type: "string", default: DEFAULT_ENTITLEMENTS },
    concurrency: { type: "string", default: "10" },
    verbose: { type: "boolean", default: false },
    help: { type: "boolean", short: "h", default: false },
  },
});

if (values.help) {
  console.log(`Usage: bun scripts/sign-macos.ts [options]

Signs the macOS .app bundle with a Developer ID identity and hardened runtime.
All files are signed in parallel for speed.

Options:
  --identity IDENTITY    Code signing identity (required)
  --app-name NAME        App bundle name (default: DuckGameRebuilt)
  --entitlements PATH    Entitlements file (default: scripts/DuckGameRebuilt.entitlements)
  --concurrency N        Max parallel codesign operations (default: 10)
  --verbose              Verbose output
  -h, --help             Show this help`);
  process.exit(0);
}

const identity = values.identity;
if (!identity) {
  console.error("Error: --identity is required.");
  console.error('Example: --identity "Developer ID Application: Your Name (TEAM_ID)"');
  console.error("\nAvailable identities:");
  await $`security find-identity -v -p codesigning`.nothrow();
  process.exit(1);
}

const appName = values["app-name"]!;
const entitlements = values.entitlements!;
const concurrency = parseInt(values.concurrency!, 10);
const verbose = values.verbose!;

const appBundle = resolve(DIST_DIR, `${appName}.app`);
const macosDir = resolve(appBundle, "Contents/MacOS");

// -- Validate inputs --
const bundleFile = Bun.file(appBundle);
if (!(await Bun.file(resolve(appBundle, "Contents/Info.plist")).exists())) {
  console.error(`Error: App bundle not found at: ${appBundle}`);
  process.exit(1);
}
if (!(await Bun.file(entitlements).exists())) {
  console.error(`Error: Entitlements file not found at: ${entitlements}`);
  process.exit(1);
}

// -- Helpers --
async function signFile(path: string, label?: string): Promise<boolean> {
  const display = label ?? basename(path);
  try {
    const result = await $`codesign --force --sign ${identity} --options runtime --timestamp --entitlements ${entitlements} ${path}`
      .quiet()
      .nothrow();
    if (result.exitCode !== 0) {
      console.error(`  [FAIL] ${display}: ${result.stderr.toString().trim()}`);
      return false;
    }
    if (verbose) console.log(`  [sign] ${display}`);
    return true;
  } catch (e) {
    console.error(`  [FAIL] ${display}: ${e}`);
    return false;
  }
}

/** Run signing jobs in batches of `concurrency` */
async function signBatch(files: { path: string; label: string }[]): Promise<number> {
  let signed = 0;
  for (let i = 0; i < files.length; i += concurrency) {
    const batch = files.slice(i, i + concurrency);
    const results = await Promise.all(batch.map((f) => signFile(f.path, f.label)));
    signed += results.filter(Boolean).length;
  }
  return signed;
}

/** Recursively collect all files under a directory */
async function collectFiles(dir: string): Promise<string[]> {
  const output = await $`find ${dir} -type f`.quiet().text();
  return output
    .trim()
    .split("\n")
    .filter((l) => l.length > 0);
}

// ============================================================
console.log(`==> Signing ${appName}.app with identity: ${identity}`);
console.log(`    Concurrency: ${concurrency}`);
console.log();

const t0 = performance.now();

// -- Step 1: Collect all files that need signing --
console.log("--- Collecting files to sign ---");

// 1a. Nested bundles (sign contents first, then the bundle itself)
const nestedBundles: string[] = [];
const nestedBundleFiles: { path: string; label: string }[] = [];

const entries = await $`ls -1 ${macosDir}`.quiet().text();
for (const entry of entries.trim().split("\n")) {
  if (entry.endsWith(".bundle") || entry.endsWith(".framework")) {
    const bundlePath = resolve(macosDir, entry);
    const stat = await Bun.file(bundlePath).exists(); // this won't work for dirs
    // Check if it's a directory
    const isDir = (await $`test -d ${bundlePath}`.nothrow().quiet()).exitCode === 0;
    if (isDir) {
      nestedBundles.push(bundlePath);
      const files = await collectFiles(bundlePath);
      for (const f of files) {
        nestedBundleFiles.push({ path: f, label: `${entry}/${relative(bundlePath, f)}` });
      }
    }
  }
}

// 1b. All other files in Contents/MacOS/ (recursive), excluding the main executable
//     and nested bundle contents (already collected above)
const allMacosFiles = await collectFiles(macosDir);
const nestedPrefixes = nestedBundles.map((b) => b + "/");
const mainExe = resolve(macosDir, "DuckGame");

const regularFiles: { path: string; label: string }[] = [];
for (const f of allMacosFiles) {
  if (f === mainExe) continue;
  if (nestedPrefixes.some((prefix) => f.startsWith(prefix))) continue;
  regularFiles.push({ path: f, label: relative(macosDir, f) });
}

const totalFiles = nestedBundleFiles.length + regularFiles.length + nestedBundles.length + 1; // +1 for main exe
console.log(`  ${nestedBundleFiles.length} files in nested bundles`);
console.log(`  ${regularFiles.length} regular files`);
console.log(`  ${totalFiles} total items to sign`);
console.log();

// -- Step 2: Sign nested bundle contents in parallel --
if (nestedBundleFiles.length > 0) {
  console.log("--- Signing nested bundle contents (parallel) ---");
  const count = await signBatch(nestedBundleFiles);
  if (!verbose) console.log(`  Signed ${count}/${nestedBundleFiles.length} files`);
}

// Sign nested bundle wrappers
for (const bundle of nestedBundles) {
  const name = basename(bundle);
  if (verbose) console.log(`  [sign] ${name} (bundle wrapper)`);
  await signFile(bundle, `${name} (bundle)`);
}

// -- Step 3: Sign all regular files in parallel --
console.log();
console.log("--- Signing all files in Contents/MacOS/ (parallel) ---");
const regularCount = await signBatch(regularFiles);
if (!verbose) console.log(`  Signed ${regularCount}/${regularFiles.length} files`);

// -- Step 4: Sign main executable --
console.log();
console.log("--- Signing main executable ---");
await signFile(mainExe, "DuckGame (main executable)");

// -- Step 5: Sign the .app bundle itself --
console.log();
console.log("--- Signing app bundle ---");
await signFile(appBundle, `${appName}.app`);

// -- Step 6: Verify --
console.log();
console.log("==> Verifying signature...");
const verify = await $`codesign --verify --deep --strict --verbose=2 ${appBundle}`.nothrow().quiet();
if (verify.exitCode === 0) {
  const elapsed = ((performance.now() - t0) / 1000).toFixed(1);
  console.log(`Code signing successful and verified in ${elapsed}s.`);
} else {
  console.error(verify.stderr.toString());
  console.error("WARNING: Signature verification reported issues.");
  process.exit(1);
}
