#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_NAME="DuckGameRebuilt"
BUNDLE_ID="com.duckgamerebuilt.app"
CONFIGURATION="Release"
IDENTITY=""
KEYCHAIN_PROFILE="DuckGameRebuilt-macos"
VERSION=""
ICON_SOURCE="DuckGame/DuckGame.ico"
VOLUME_NAME="DuckGameRebuilt"
DMG_NAME=""
SIGN_CONCURRENCY="10"
ENTITLEMENTS="$ROOT_DIR/scripts/DuckGameRebuilt.entitlements"

SKIP_BUILD=0
SKIP_NOTARIZE=0
NO_SIGN=0
VERBOSE=0

print_help() {
  cat <<'EOF'
Usage: ./scripts/release-macos.sh [options]

Runs the full macOS Mono release pipeline:
  1) Build output (optional)
  2) Package .app and .dmg
  3) Sign app and dmg
  4) Notarize and staple (optional)

Options:
  --identity IDENTITY      Developer ID identity for signing
  --configuration CONFIG   Build configuration (default: Release)
  --keychain-profile NAME  notarytool keychain profile (default: DuckGameRebuilt-macos)
  --app-name NAME          App bundle name (default: DuckGameRebuilt)
  --bundle-id ID           CFBundleIdentifier (default: com.duckgamerebuilt.app)
  --version VERSION        Version string (default: git short hash)
  --icon-source PATH       Icon source file (default: DuckGame/DuckGame.ico)
  --volume-name NAME       DMG volume name (default: DuckGameRebuilt)
  --dmg-name NAME          DMG file name (default: <app>-macos-mono-<arch>.dmg)
  --sign-concurrency N     Parallel signing jobs (default: 10)
  --entitlements PATH      Entitlements file path
  --skip-build             Skip build step before packaging
  --skip-notarize          Skip notarization
  --no-sign                Skip signing
  --verbose                Verbose notarization output
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity)
      IDENTITY="${2:-}"
      shift
      ;;
    --configuration)
      CONFIGURATION="${2:-}"
      shift
      ;;
    --keychain-profile)
      KEYCHAIN_PROFILE="${2:-}"
      shift
      ;;
    --app-name)
      APP_NAME="${2:-}"
      shift
      ;;
    --bundle-id)
      BUNDLE_ID="${2:-}"
      shift
      ;;
    --version)
      VERSION="${2:-}"
      shift
      ;;
    --icon-source)
      ICON_SOURCE="${2:-}"
      shift
      ;;
    --volume-name)
      VOLUME_NAME="${2:-}"
      shift
      ;;
    --dmg-name)
      DMG_NAME="${2:-}"
      shift
      ;;
    --sign-concurrency)
      SIGN_CONCURRENCY="${2:-}"
      shift
      ;;
    --entitlements)
      ENTITLEMENTS="${2:-}"
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      ;;
    --no-sign)
      NO_SIGN=1
      ;;
    --verbose)
      VERBOSE=1
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_help
      exit 1
      ;;
  esac
  shift
done

if [[ "$NO_SIGN" -eq 0 && -z "$IDENTITY" ]]; then
  echo "Error: --identity is required unless --no-sign is used." >&2
  security find-identity -v -p codesigning || true
  exit 1
fi

if [[ "$SKIP_NOTARIZE" -eq 0 && "$NO_SIGN" -eq 1 ]]; then
  echo "Error: notarization requires signed artifacts. Remove --no-sign or add --skip-notarize." >&2
  exit 1
fi

echo "============================================================"
echo "DuckGameRebuilt macOS Mono release pipeline"
echo "============================================================"
echo "App: $APP_NAME"
echo "Configuration: $CONFIGURATION"
echo "Skip build: $SKIP_BUILD"
echo "Skip notarize: $SKIP_NOTARIZE"
echo "Signing: $((1 - NO_SIGN))"

PACKAGE_CMD=(
  "$ROOT_DIR/scripts/package-macos.sh"
  --configuration "$CONFIGURATION"
  --app-name "$APP_NAME"
  --bundle-id "$BUNDLE_ID"
  --icon-source "$ICON_SOURCE"
  --volume-name "$VOLUME_NAME"
  --dmg
  --sign-concurrency "$SIGN_CONCURRENCY"
  --entitlements "$ENTITLEMENTS"
)

if [[ "$SKIP_BUILD" -eq 1 ]]; then
  PACKAGE_CMD+=(--skip-build)
fi

if [[ -n "$VERSION" ]]; then
  PACKAGE_CMD+=(--version "$VERSION")
fi

if [[ -n "$DMG_NAME" ]]; then
  PACKAGE_CMD+=(--dmg-name "$DMG_NAME")
fi

if [[ "$NO_SIGN" -eq 1 ]]; then
  PACKAGE_CMD+=(--no-sign)
else
  PACKAGE_CMD+=(--sign-identity "$IDENTITY")
fi

"${PACKAGE_CMD[@]}"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  NOTARIZE_CMD=(
    "$ROOT_DIR/scripts/notarize-macos.sh"
    --app-name "$APP_NAME"
    --keychain-profile "$KEYCHAIN_PROFILE"
  )
  if [[ -n "$DMG_NAME" ]]; then
    NOTARIZE_CMD+=(--dmg-name "$DMG_NAME")
  fi
  if [[ "$VERBOSE" -eq 1 ]]; then
    NOTARIZE_CMD+=(--verbose)
  fi

  "${NOTARIZE_CMD[@]}"
fi

echo "Release pipeline complete."
