#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SCRIPT="$ROOT_DIR/scripts/package-macos-app.sh"
DIST_DIR="$ROOT_DIR/dist/macos"

APP_NAME="DuckGameRebuilt"
VOLUME_NAME="DuckGameRebuilt"
DMG_NAME="DuckGameRebuilt-macos-arm64.dmg"
ICON_SOURCE=""
SKIP_APP=0
SKIP_PUBLISH=0
SIGN_APP=1
BUNDLE_ID="com.duckgamerebuilt.app"
APP_VERSION=""

usage() {
  cat <<'EOF'
Usage: package-macos-dmg.sh [options]

Builds a distributable .dmg containing the macOS app bundle.

Options:
  --skip-app           Do not rebuild the .app before creating DMG
  --skip-publish       Pass through to app packaging step
  --no-sign            Pass through to app packaging step
  --app-name NAME      App bundle name (default: DuckGameRebuilt)
  --bundle-id ID       CFBundleIdentifier for app packaging
  --version VERSION    Version string for app packaging
  --icon-source PATH   Pass through custom icon path to app packaging
  --volume-name NAME   DMG volume name (default: DuckGameRebuilt)
  --dmg-name NAME      Output DMG filename (default: DuckGameRebuilt-macos-arm64.dmg)
  -h, --help           Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-app)
      SKIP_APP=1
      shift
      ;;
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
    --volume-name)
      VOLUME_NAME="$2"
      shift 2
      ;;
    --dmg-name)
      DMG_NAME="$2"
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

if [[ "$SKIP_APP" -eq 0 ]]; then
  app_args=(--app-name "$APP_NAME" --bundle-id "$BUNDLE_ID")
  if [[ "$SKIP_PUBLISH" -eq 1 ]]; then
    app_args+=(--skip-publish)
  fi
  if [[ "$SIGN_APP" -eq 0 ]]; then
    app_args+=(--no-sign)
  fi
  if [[ -n "$APP_VERSION" ]]; then
    app_args+=(--version "$APP_VERSION")
  fi
  if [[ -n "$ICON_SOURCE" ]]; then
    app_args+=(--icon-source "$ICON_SOURCE")
  fi
  bash "$APP_SCRIPT" "${app_args[@]}"
fi

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found at: $APP_BUNDLE" >&2
  echo "Run scripts/package-macos-app.sh first or omit --skip-app." >&2
  exit 1
fi

STAGE_DIR="$DIST_DIR/.dmg-staging"
DMG_PATH="$DIST_DIR/$DMG_NAME"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_BUNDLE" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGE_DIR"
echo "Created DMG: $DMG_PATH"
