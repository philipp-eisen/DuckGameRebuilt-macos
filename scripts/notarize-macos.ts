#!/usr/bin/env bun
/**
 * notarize-macos.ts -- Submit a signed .app and/or .dmg to Apple for notarization,
 * then staple the notarization ticket.
 *
 * Usage:
 *   bun scripts/notarize-macos.ts [options]
 *
 * Prerequisites:
 *   xcrun notarytool store-credentials "DuckGameRebuilt-macos" \
 *     --apple-id "you@email.com" --team-id "TEAM_ID" --password "app-specific-pw"
 */
import { $ } from "bun";
import { resolve } from "path";
import { parseArgs } from "util";

const ROOT_DIR = resolve(import.meta.dir, "..");
const DIST_DIR = resolve(ROOT_DIR, "dist/macos");

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    "app-name": { type: "string", default: "DuckGameRebuilt" },
    "dmg-name": { type: "string", default: "DuckGameRebuilt-macos-arm64.dmg" },
    "keychain-profile": { type: "string", default: "DuckGameRebuilt-macos" },
    "app-only": { type: "boolean", default: false },
    "dmg-only": { type: "boolean", default: false },
    "no-staple": { type: "boolean", default: false },
    verbose: { type: "boolean", default: false },
    help: { type: "boolean", short: "h", default: false },
  },
});

if (values.help) {
  console.log(`Usage: bun scripts/notarize-macos.ts [options]

Submits signed .app and .dmg to Apple for notarization and staples the ticket.

Options:
  --app-name NAME          App bundle name (default: DuckGameRebuilt)
  --dmg-name NAME          DMG filename (default: DuckGameRebuilt-macos-arm64.dmg)
  --keychain-profile NAME  Keychain profile (default: DuckGameRebuilt-macos)
  --app-only               Only notarize the .app
  --dmg-only               Only notarize the .dmg
  --no-staple              Submit but don't staple
  --verbose                Verbose output
  -h, --help               Show this help`);
  process.exit(0);
}

const appName = values["app-name"]!;
const dmgName = values["dmg-name"]!;
const keychainProfile = values["keychain-profile"]!;
const notarizeApp = !values["dmg-only"];
const notarizeDmg = !values["app-only"];
const staple = !values["no-staple"];
const verbose = values.verbose!;

const appBundle = resolve(DIST_DIR, `${appName}.app`);
const dmgPath = resolve(DIST_DIR, dmgName);

async function submitAndWait(artifact: string, label: string): Promise<boolean> {
  console.log(`==> Submitting ${label} for notarization...`);

  const args = ["xcrun", "notarytool", "submit", artifact, "--keychain-profile", keychainProfile, "--wait"];
  if (verbose) args.push("--verbose");

  const result = await $`${args}`.nothrow().quiet();
  const output = result.stdout.toString() + result.stderr.toString();

  if (result.exitCode !== 0) {
    console.error(`Notarization submission failed for ${label}:`);
    console.error(output);
    // Try to fetch the log
    const idMatch = output.match(/id:\s*([a-f0-9-]+)/);
    if (idMatch) {
      console.error(`\nFetching log for submission ${idMatch[1]}...`);
      await $`xcrun notarytool log ${idMatch[1]} --keychain-profile ${keychainProfile}`.nothrow();
    }
    return false;
  }

  console.log(output);

  if (output.includes("status: Accepted")) {
    console.log(`Notarization accepted for ${label}.`);
    return true;
  } else if (output.includes("status: Invalid")) {
    console.error(`Notarization REJECTED for ${label}.`);
    const idMatch = output.match(/id:\s*([a-f0-9-]+)/);
    if (idMatch) {
      console.error("Fetching rejection log...");
      await $`xcrun notarytool log ${idMatch[1]} --keychain-profile ${keychainProfile}`.nothrow();
    }
    return false;
  }

  console.warn(`WARNING: Unexpected notarization status for ${label}. Check output above.`);
  return true; // Assume success if no explicit rejection
}

async function stapleArtifact(artifact: string, label: string) {
  if (!staple) {
    console.log(`  [skip] Stapling disabled for ${label}`);
    return;
  }
  console.log(`==> Stapling notarization ticket to ${label}...`);
  await $`xcrun stapler staple ${artifact}`;
  console.log(`Stapled ${label}.`);
}

async function validateArtifact(artifact: string, label: string) {
  console.log(`==> Validating ${label}...`);
  const result = await $`xcrun stapler validate ${artifact}`.nothrow().quiet();
  if (result.exitCode === 0) {
    console.log(`Validation passed for ${label}.`);
  } else {
    console.warn(`WARNING: Stapler validation failed for ${label}.`);
    console.warn(result.stderr.toString());
  }
}

// -- Notarize .app --
if (notarizeApp) {
  if (!(await Bun.file(resolve(appBundle, "Contents/Info.plist")).exists())) {
    console.error(`Error: App bundle not found at: ${appBundle}`);
    process.exit(1);
  }

  // notarytool requires .zip, .dmg, or .pkg -- zip the .app
  const appZip = resolve(DIST_DIR, `${appName}.zip`);
  console.log(`==> Creating ZIP of ${appName}.app for submission...`);
  await $`rm -f ${appZip}`;
  await $`ditto -c -k --keepParent ${appBundle} ${appZip}`;
  console.log(`Created: ${appZip}\n`);

  const success = await submitAndWait(appZip, `${appName}.app`);
  if (success) {
    console.log();
    await stapleArtifact(appBundle, `${appName}.app`);
    console.log();
    await validateArtifact(appBundle, `${appName}.app`);
  } else {
    console.error(`\nFAILED: Notarization of ${appName}.app was not successful.`);
    process.exit(1);
  }

  await $`rm -f ${appZip}`;
  console.log();
}

// -- Notarize .dmg --
if (notarizeDmg) {
  if (!(await Bun.file(dmgPath).exists())) {
    console.error(`Error: DMG not found at: ${dmgPath}`);
    if (notarizeApp) {
      console.error("Skipping DMG notarization (app was notarized successfully).");
      process.exit(0);
    }
    process.exit(1);
  }

  console.log();
  const success = await submitAndWait(dmgPath, dmgName);
  if (success) {
    console.log();
    await stapleArtifact(dmgPath, dmgName);
    console.log();
    await validateArtifact(dmgPath, dmgName);
  } else {
    console.error(`\nFAILED: Notarization of ${dmgName} was not successful.`);
    process.exit(1);
  }
}

console.log("\n==> Notarization complete.");
