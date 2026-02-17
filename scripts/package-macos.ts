#!/usr/bin/env bun
/**
 * package-macos.ts -- Package the macOS build into a .app bundle and optional .dmg.
 *
 * Usage:
 *   bun scripts/package-macos.ts [options]
 *   bun scripts/package-macos.ts --dmg                # also create .dmg
 *   bun scripts/package-macos.ts --arch x64 --dmg     # build for Intel
 */
import { $ } from "bun";
import { resolve, isAbsolute } from "path";
import { existsSync, mkdirSync } from "fs";
import { parseArgs } from "util";

const ROOT_DIR = resolve(import.meta.dir, "..");

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    arch: { type: "string", default: "arm64" },
    "skip-publish": { type: "boolean", default: false },
    "no-sign": { type: "boolean", default: false },
    "sign-identity": { type: "string", default: "" },
    "app-name": { type: "string", default: "DuckGameRebuilt" },
    "bundle-id": { type: "string", default: "com.duckgamerebuilt.app" },
    version: { type: "string", default: "" },
    "icon-source": { type: "string", default: "DuckGame/DuckGame.ico" },
    dmg: { type: "boolean", default: false },
    "volume-name": { type: "string", default: "DuckGameRebuilt" },
    "dmg-name": { type: "string", default: "" },
    help: { type: "boolean", short: "h", default: false },
  },
});

if (values.help) {
  console.log(`Usage: bun scripts/package-macos.ts [options]

Packages the macOS build into a .app bundle and optional .dmg.

Options:
  --arch ARCH            Target architecture: arm64 (default) or x64
  --skip-publish         Skip the dotnet publish step
  --no-sign              Skip code signing entirely
  --sign-identity ID     Developer ID for real code signing
  --app-name NAME        App bundle name (default: DuckGameRebuilt)
  --bundle-id ID         CFBundleIdentifier (default: com.duckgamerebuilt.app)
  --version VERSION      Version string (default: git short hash)
  --icon-source PATH     Icon source file (default: DuckGame/DuckGame.ico)
  --dmg                  Also create a .dmg installer
  --volume-name NAME     DMG volume name (default: DuckGameRebuilt)
  --dmg-name NAME        DMG filename (default: DuckGameRebuilt-macos-<arch>.dmg)
  -h, --help             Show this help`);
  process.exit(0);
}

const arch = values.arch!;
if (arch !== "arm64" && arch !== "x64") {
  console.error(`Error: --arch must be "arm64" or "x64", got "${arch}"`);
  process.exit(1);
}

const rid = `osx-${arch}`;
const PUBLISH_DIR = resolve(ROOT_DIR, `DuckGame/bin/Release/net8.0/${rid}/publish`);
const DIST_DIR = resolve(ROOT_DIR, "dist/macos");

const appName = values["app-name"]!;
const bundleId = values["bundle-id"]!;
const signIdentity = values["sign-identity"]!;
const createDmg = values.dmg!;
const volumeName = values["volume-name"]!;
const dmgName = values["dmg-name"] || `DuckGameRebuilt-macos-${arch}.dmg`;

let appVersion = values.version!;
if (!appVersion) {
  appVersion = (await $`git -C ${ROOT_DIR} rev-parse --short HEAD`.nothrow().quiet().text()).trim() || "dev";
}

let iconSource = values["icon-source"]!;
if (!isAbsolute(iconSource)) iconSource = resolve(ROOT_DIR, iconSource);

// -- Step 1: Publish if needed --
if (!values["skip-publish"]) {
  console.log(`==> Running publish for ${rid}...`);
  await $`bun ${resolve(ROOT_DIR, "scripts/publish-macos.ts")} --arch ${arch}`;
  console.log();
}

const mainExe = resolve(PUBLISH_DIR, "DuckGame");
if (!existsSync(mainExe)) {
  console.error(`Missing published executable at: ${mainExe}`);
  console.error(`Run bun scripts/publish-macos.ts --arch ${arch} first or use --skip-publish.`);
  process.exit(1);
}

// -- Step 2: Build .app bundle --
const appBundle = resolve(DIST_DIR, `${appName}.app`);
const macosDir = resolve(appBundle, "Contents/MacOS");
const resourcesDir = resolve(appBundle, "Contents/Resources");
const plistPath = resolve(appBundle, "Contents/Info.plist");

console.log(`==> Building ${appName}.app (${rid})`);
await $`rm -rf ${appBundle}`;
mkdirSync(macosDir, { recursive: true });
await $`cp -R ${PUBLISH_DIR}/. ${macosDir}/`;

// -- Step 3: Generate app icon --
let iconPlistBlock = "";
if (existsSync(iconSource)) {
  try {
    const tmpDir = (await $`mktemp -d`.quiet().text()).trim();
    const basePng = resolve(tmpDir, "base.png");
    const iconsetDir = resolve(tmpDir, "AppIcon.iconset");
    mkdirSync(iconsetDir, { recursive: true });

    await $`sips -s format png ${iconSource} --out ${basePng}`.quiet();
    await $`sips -z 1024 1024 ${basePng} --out ${basePng}`.quiet();

    const sizes = [16, 32, 128, 256, 512];
    for (const size of sizes) {
      const retina = size * 2;
      await $`sips -z ${size} ${size} ${basePng} --out ${iconsetDir}/icon_${size}x${size}.png`.quiet();
      await $`sips -z ${retina} ${retina} ${basePng} --out ${iconsetDir}/icon_${size}x${size}@2x.png`.quiet();
    }

    mkdirSync(resourcesDir, { recursive: true });
    await $`iconutil -c icns ${iconsetDir} -o ${resourcesDir}/AppIcon.icns`;

    iconPlistBlock = `  <key>CFBundleIconFile</key>\n  <string>AppIcon</string>`;
    console.log(`  Using icon: ${iconSource}`);
    await $`rm -rf ${tmpDir}`;
  } catch {
    console.warn("  Could not generate app icon, continuing without one.");
  }
} else {
  console.warn("  No icon source found, continuing without app icon.");
}

// -- Step 4: Write Info.plist --
const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${appName}</string>
${iconPlistBlock}
  <key>CFBundleExecutable</key>
  <string>DuckGame</string>
  <key>CFBundleIdentifier</key>
  <string>${bundleId}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${appName}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${appVersion}</string>
  <key>CFBundleVersion</key>
  <string>${appVersion}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
`;
await Bun.write(plistPath, plist);

// -- Step 5: Sign --
if (!values["no-sign"]) {
  if (signIdentity) {
    console.log();
    await $`bun ${resolve(ROOT_DIR, "scripts/sign-macos.ts")} --identity ${signIdentity} --app-name ${appName}`;
  } else {
    console.log("  Ad-hoc signing for local development...");
    await $`codesign --force --deep --sign - ${appBundle}`;
  }
}

console.log(`\nCreated app bundle: ${appBundle}`);

// -- Step 6: Create DMG if requested --
if (createDmg) {
  console.log(`\n==> Creating DMG: ${dmgName}`);
  const stageDir = resolve(DIST_DIR, ".dmg-staging");
  const dmgPath = resolve(DIST_DIR, dmgName);

  await $`rm -rf ${stageDir}`;
  mkdirSync(stageDir, { recursive: true });
  await $`cp -R ${appBundle} ${stageDir}/`;
  await $`ln -s /Applications ${stageDir}/Applications`;

  await $`rm -f ${dmgPath}`;
  await $`hdiutil create -volname ${volumeName} -srcfolder ${stageDir} -ov -format UDZO ${dmgPath}`;
  await $`rm -rf ${stageDir}`;

  if (signIdentity) {
    console.log(`  Signing DMG with identity: ${signIdentity}`);
    await $`codesign --force --sign ${signIdentity} --timestamp ${dmgPath}`;
  }

  console.log(`Created DMG: ${dmgPath}`);
}
