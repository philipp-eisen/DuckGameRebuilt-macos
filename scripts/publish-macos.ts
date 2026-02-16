#!/usr/bin/env bun
/**
 * publish-macos.ts -- Build and publish the .NET 8 macOS arm64 build.
 *
 * Usage:
 *   bun scripts/publish-macos.ts
 */
import { $ } from "bun";
import { resolve } from "path";
import { existsSync } from "fs";
import { parseArgs } from "util";

const ROOT_DIR = resolve(import.meta.dir, "..");
const PUBLISH_DIR = resolve(ROOT_DIR, "DuckGame/bin/Release/net8.0/osx-arm64/publish");
const NATIVE_DIR = resolve(ROOT_DIR, "DuckGame/build/native/osx-arm64");

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    help: { type: "boolean", short: "h", default: false },
  },
});

if (values.help) {
  console.log(`Usage: bun scripts/publish-macos.ts

Builds the .NET 8 macOS arm64 self-contained publish and stages assets.`);
  process.exit(0);
}

// -- Clean and publish --
await $`rm -rf ${PUBLISH_DIR}`;
await $`dotnet publish ${resolve(ROOT_DIR, "DuckGame/DuckGame.Net8.csproj")} -c Release -r osx-arm64 --self-contained true /p:PublishSingleFile=false`;

// -- Patch Steamworks --
const steamworksPath = resolve(PUBLISH_DIR, "Steamworks.NET.dll");
if (existsSync(steamworksPath)) {
  await $`dotnet run --project ${resolve(ROOT_DIR, "scripts/SteamworksPatcher/SteamworksPatcher.csproj")} -- ${steamworksPath}`;
}

// -- Copy native dylibs --
if (existsSync(NATIVE_DIR)) {
  const dylibs = new Bun.Glob("*.dylib").scanSync(NATIVE_DIR);
  for (const dylib of dylibs) {
    await $`cp ${resolve(NATIVE_DIR, dylib)} ${PUBLISH_DIR}/`;
  }
}

// -- Copy game content --
const deps = resolve(ROOT_DIR, "deps");
if (existsSync(resolve(deps, "Content"))) {
  await $`cp -R ${resolve(deps, "Content")} ${resolve(PUBLISH_DIR, "Content")}`;
}
if (existsSync(resolve(deps, "spriteatlas"))) {
  await $`cp -R ${resolve(deps, "spriteatlas")} ${resolve(PUBLISH_DIR, "spriteatlas")}`;
}
for (const asset of ["lang.txt", "gamecontrollerdb.txt", "MonoFont.ttf"]) {
  const src = resolve(deps, asset);
  if (existsSync(src)) await $`cp ${src} ${resolve(PUBLISH_DIR, asset)}`;
}

// -- Copy Steam API bundle --
const steamBundlePaths = [
  resolve(deps, "steam_api.bundle"),
  resolve(deps, "OSX-Linux-x64/steam_api.bundle"),
];
for (const bundleSrc of steamBundlePaths) {
  if (existsSync(bundleSrc)) {
    await $`cp -R ${bundleSrc} ${resolve(PUBLISH_DIR, "steam_api.bundle")}`;
    break;
  }
}

// Copy steam_api dylib to expected names
const steamDylib = resolve(PUBLISH_DIR, "steam_api.bundle/Contents/MacOS/libsteam_api.dylib");
if (existsSync(steamDylib)) {
  await $`cp ${steamDylib} ${resolve(PUBLISH_DIR, "steam_api64.dylib")}`;
  await $`cp ${steamDylib} ${resolve(PUBLISH_DIR, "libsteam_api64.dylib")}`;
}

// -- Fix dylib install names --
const sdlDylib = resolve(PUBLISH_DIR, "libSDL2-2.0.0.dylib");
if (existsSync(sdlDylib)) {
  await $`install_name_tool -id "@rpath/libSDL2-2.0.0.dylib" ${sdlDylib}`.nothrow();
}

for (const name of ["libFNA3D.0.dylib", "libFAudio.0.dylib"]) {
  const dylib = resolve(PUBLISH_DIR, name);
  if (existsSync(dylib)) {
    await $`install_name_tool -change "/opt/homebrew/opt/sdl2/lib/libSDL2-2.0.0.dylib" "@rpath/libSDL2-2.0.0.dylib" ${dylib}`.nothrow();
    await $`install_name_tool -change "/opt/homebrew/lib/libSDL2-2.0.0.dylib" "@rpath/libSDL2-2.0.0.dylib" ${dylib}`.nothrow();
  }
}

// -- Ad-hoc sign dylibs for local dev (release signing replaces these) --
for (const name of ["libSDL2-2.0.0.dylib", "libFNA3D.0.dylib", "libFAudio.0.dylib"]) {
  const dylib = resolve(PUBLISH_DIR, name);
  if (existsSync(dylib)) {
    await $`codesign --force --sign - ${dylib}`.nothrow().quiet();
  }
}

console.log(`Published to: ${PUBLISH_DIR}`);
