#!/usr/bin/env bun
/**
 * release-macos.ts -- Full macOS release pipeline:
 *   1. Build & publish (.NET 8 macOS)
 *   2. Package .app bundle
 *   3. Sign with Developer ID + hardened runtime (parallel)
 *   4. Package .dmg and sign it
 *   5. Notarize .app and .dmg with Apple
 *   6. Staple notarization tickets
 *
 * Usage:
 *   bun scripts/release-macos.ts --identity "Developer ID Application: Name (TEAM_ID)" [--arch arm64|x64]
 */
import { $ } from "bun";
import { resolve } from "path";
import { parseArgs } from "util";

const ROOT_DIR = resolve(import.meta.dir, "..");
const DIST_DIR = resolve(ROOT_DIR, "dist/macos");

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    arch: { type: "string", default: "arm64" },
    identity: { type: "string" },
    "keychain-profile": { type: "string", default: "DuckGameRebuilt-macos" },
    "app-name": { type: "string", default: "DuckGameRebuilt" },
    "bundle-id": { type: "string", default: "com.duckgamerebuilt.app" },
    version: { type: "string", default: "" },
    "dmg-name": { type: "string", default: "" },
    "skip-publish": { type: "boolean", default: false },
    "skip-notarize": { type: "boolean", default: false },
    concurrency: { type: "string", default: "10" },
    verbose: { type: "boolean", default: false },
    help: { type: "boolean", short: "h", default: false },
  },
});

if (values.help) {
  console.log(`Usage: bun scripts/release-macos.ts [options]

Full macOS release pipeline: build, sign (parallel), package, notarize, staple.

Options:
  --arch ARCH                Target architecture: arm64 (default) or x64
  --identity IDENTITY        Code signing identity (required)
  --keychain-profile NAME    Notarytool keychain profile (default: DuckGameRebuilt-macos)
  --app-name NAME            App bundle name (default: DuckGameRebuilt)
  --bundle-id ID             CFBundleIdentifier (default: com.duckgamerebuilt.app)
  --version VERSION          Version string (default: git short hash)
  --dmg-name NAME            DMG filename (default: DuckGameRebuilt-macos-<arch>.dmg)
  --skip-publish             Skip dotnet publish (reuse existing build)
  --skip-notarize            Build and sign only, skip notarization
  --concurrency N            Parallel signing operations (default: 10)
  --verbose                  Verbose output
  -h, --help                 Show this help`);
  process.exit(0);
}

const arch = values.arch!;
if (arch !== "arm64" && arch !== "x64") {
  console.error(`Error: --arch must be "arm64" or "x64", got "${arch}"`);
  process.exit(1);
}

const identity = values.identity;
if (!identity) {
  console.error("Error: --identity is required.");
  console.error("");
  console.error("Available Developer ID identities:");
  await $`security find-identity -v -p codesigning`.nothrow();
  console.error("");
  console.error('Usage: bun scripts/release-macos.ts --identity "Developer ID Application: Your Name (TEAM_ID)"');
  process.exit(1);
}

const appName = values["app-name"]!;
const keychainProfile = values["keychain-profile"]!;
const dmgName = values["dmg-name"] || `DuckGameRebuilt-macos-${arch}.dmg`;
const concurrency = values.concurrency!;

console.log("============================================================");
console.log("  DuckGameRebuilt macOS Release Pipeline");
console.log("============================================================");
console.log();
console.log(`  Arch:        ${arch}`);
console.log(`  Identity:    ${identity}`);
console.log(`  Keychain:    ${keychainProfile}`);
console.log(`  App Name:    ${appName}`);
console.log(`  DMG Name:    ${dmgName}`);
console.log(`  Concurrency: ${concurrency}`);
console.log();

const t0 = performance.now();

// -- Step 1: Build, package .app, sign, and create .dmg --
console.log("============================================================");
console.log("  Step 1: Build, package, sign, and create DMG");
console.log("============================================================");
console.log();

const packageArgs = [
  resolve(ROOT_DIR, "scripts/package-macos.ts"),
  "--arch", arch,
  "--sign-identity", identity,
  "--app-name", appName,
  "--bundle-id", values["bundle-id"]!,
  "--dmg-name", dmgName,
  "--dmg",
];
if (values["skip-publish"]) packageArgs.push("--skip-publish");
if (values.version) packageArgs.push("--version", values.version);

await $`bun ${packageArgs}`;

console.log();
console.log("Build, packaging, and signing complete.");
console.log();

// -- Step 2: Notarize --
if (values["skip-notarize"]) {
  console.log("============================================================");
  console.log("  Skipping notarization (--skip-notarize)");
  console.log("============================================================");
} else {
  console.log("============================================================");
  console.log("  Step 2: Notarize with Apple");
  console.log("============================================================");
  console.log();

  const notarizeArgs = [
    resolve(ROOT_DIR, "scripts/notarize-macos.ts"),
    "--app-name", appName,
    "--dmg-name", dmgName,
    "--keychain-profile", keychainProfile,
  ];
  if (values.verbose) notarizeArgs.push("--verbose");

  await $`bun ${notarizeArgs}`;
}

const elapsed = ((performance.now() - t0) / 1000).toFixed(1);

console.log();
console.log("============================================================");
console.log("  Release Complete");
console.log("============================================================");
console.log();
console.log(`  App:     ${resolve(DIST_DIR, `${appName}.app`)}`);
console.log(`  DMG:     ${resolve(DIST_DIR, dmgName)}`);
console.log(`  Time:    ${elapsed}s`);
console.log();
console.log("Verification commands:");
console.log(`  codesign --verify --deep --strict -v ${resolve(DIST_DIR, `${appName}.app`)}`);
console.log(`  spctl --assess --type execute -v ${resolve(DIST_DIR, `${appName}.app`)}`);
console.log(`  stapler validate ${resolve(DIST_DIR, `${appName}.app`)}`);
console.log(`  stapler validate ${resolve(DIST_DIR, dmgName)}`);
console.log();
