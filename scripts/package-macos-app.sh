#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH_SCRIPT="$ROOT_DIR/scripts/publish-macos-arm64.sh"
PUBLISH_DIR="$ROOT_DIR/DuckGame/bin/Release/net8.0/osx-arm64/publish"
DIST_DIR="$ROOT_DIR/dist/macos"

APP_NAME="DuckGameRebuilt"
BUNDLE_ID="com.duckgamerebuilt.app"
APP_VERSION=""
ICON_SOURCE="$ROOT_DIR/DuckGame/DuckGame.ico"
SKIP_PUBLISH=0
SIGN_APP=1

generate_app_icon() {
  local source_path="$1"
  local resources_dir="$2"

  if [[ ! -f "$source_path" ]]; then
    echo "Icon source not found: $source_path" >&2
    return 1
  fi
  if ! command -v sips > /dev/null 2>&1; then
    echo "sips not found, skipping .icns generation" >&2
    return 1
  fi
  if ! command -v iconutil > /dev/null 2>&1; then
    echo "iconutil not found, skipping .icns generation" >&2
    return 1
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local base_png="$tmp_dir/base.png"
  local iconset_dir="$tmp_dir/AppIcon.iconset"
  mkdir -p "$iconset_dir"

  if ! sips -s format png "$source_path" --out "$base_png" > /dev/null; then
    echo "Failed to convert icon source to PNG: $source_path" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  sips -z 1024 1024 "$base_png" --out "$base_png" > /dev/null

  local sizes=(16 32 128 256 512)
  local size
  local retina
  for size in "${sizes[@]}"; do
    retina=$((size * 2))
    sips -z "$size" "$size" "$base_png" --out "$iconset_dir/icon_${size}x${size}.png" > /dev/null
    sips -z "$retina" "$retina" "$base_png" --out "$iconset_dir/icon_${size}x${size}@2x.png" > /dev/null
  done

  mkdir -p "$resources_dir"
  if ! iconutil -c icns "$iconset_dir" -o "$resources_dir/AppIcon.icns"; then
    echo "Failed to generate AppIcon.icns" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  rm -rf "$tmp_dir"
  return 0
}

usage() {
  cat <<'EOF'
Usage: package-macos-app.sh [options]

Builds a standalone .app bundle from the net8 macOS publish output.

Options:
  --skip-publish       Do not run scripts/publish-macos-arm64.sh first
  --no-sign            Skip ad-hoc codesigning of the .app bundle
  --app-name NAME      App bundle name (default: DuckGameRebuilt)
  --bundle-id ID       CFBundleIdentifier value
  --version VERSION    CFBundleVersion/CFBundleShortVersionString value
  --icon-source PATH   Path to source icon (.ico/.png/.jpg/.tiff)
  -h, --help           Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-publish)
      SKIP_PUBLISH=1
      shift
      ;;
    --no-sign)
      SIGN_APP=0
      shift
      ;;
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --version)
      APP_VERSION="$2"
      shift 2
      ;;
    --icon-source)
      ICON_SOURCE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$APP_VERSION" ]]; then
  APP_VERSION="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'dev')"
fi

if [[ "$ICON_SOURCE" != /* ]]; then
  ICON_SOURCE="$ROOT_DIR/$ICON_SOURCE"
fi

if [[ "$SKIP_PUBLISH" -eq 0 ]]; then
  bash "$PUBLISH_SCRIPT"
fi

if [[ ! -x "$PUBLISH_DIR/DuckGame" ]]; then
  echo "Missing published game executable at: $PUBLISH_DIR/DuckGame" >&2
  echo "Run scripts/publish-macos-arm64.sh first or omit --skip-publish." >&2
  exit 1
fi

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
PLIST_PATH="$APP_BUNDLE/Contents/Info.plist"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
cp -R "$PUBLISH_DIR/." "$MACOS_DIR/"

ICON_PLIST_BLOCK=""
if generate_app_icon "$ICON_SOURCE" "$RESOURCES_DIR"; then
  ICON_PLIST_BLOCK=$'  <key>CFBundleIconFile</key>\n  <string>AppIcon</string>'
  echo "Using app icon source: $ICON_SOURCE"
else
  echo "Continuing without custom app icon." >&2
fi

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
${ICON_PLIST_BLOCK}
  <key>CFBundleExecutable</key>
  <string>DuckGame</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

if [[ "$SIGN_APP" -eq 1 ]]; then
  if command -v codesign > /dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE"
  else
    echo "codesign not found, skipping ad-hoc signing" >&2
  fi
fi

echo "Created app bundle: $APP_BUNDLE"
