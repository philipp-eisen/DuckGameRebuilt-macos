#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/macos"

APP_NAME="DuckGameRebuilt"
HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" == "x86_64" ]]; then
  HOST_ARCH="x64"
elif [[ "$HOST_ARCH" == "arm64" ]]; then
  HOST_ARCH="arm64"
fi

DMG_NAME="DuckGameRebuilt-macos-mono-${HOST_ARCH}.dmg"
KEYCHAIN_PROFILE="DuckGameRebuilt-macos"
APP_ONLY=0
DMG_ONLY=0
NO_STAPLE=0
VERBOSE=0

print_help() {
  cat <<'EOF'
Usage: ./scripts/notarize-macos.sh [options]

Submits a signed .app and/or .dmg to Apple notary service and staples tickets.

Options:
  --app-name NAME          App bundle name (default: DuckGameRebuilt)
  --dmg-name NAME          DMG file name (default: DuckGameRebuilt-macos-mono-<arch>.dmg)
  --keychain-profile NAME  notarytool keychain profile (default: DuckGameRebuilt-macos)
  --app-only               Only notarize the .app
  --dmg-only               Only notarize the .dmg
  --no-staple              Skip stapling and stapler validation
  --verbose                Enable verbose notarytool output
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      APP_NAME="${2:-}"
      shift
      ;;
    --dmg-name)
      DMG_NAME="${2:-}"
      shift
      ;;
    --keychain-profile)
      KEYCHAIN_PROFILE="${2:-}"
      shift
      ;;
    --app-only)
      APP_ONLY=1
      ;;
    --dmg-only)
      DMG_ONLY=1
      ;;
    --no-staple)
      NO_STAPLE=1
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

if [[ "$APP_ONLY" -eq 1 && "$DMG_ONLY" -eq 1 ]]; then
  echo "Error: --app-only and --dmg-only cannot be used together." >&2
  exit 1
fi

NOTARIZE_APP=1
NOTARIZE_DMG=1
if [[ "$APP_ONLY" -eq 1 ]]; then
  NOTARIZE_DMG=0
fi
if [[ "$DMG_ONLY" -eq 1 ]]; then
  NOTARIZE_APP=0
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

submit_and_wait() {
  local artifact="$1"
  local label="$2"
  local output=""

  echo "==> Submitting $label for notarization"
  if [[ "$VERBOSE" -eq 1 ]]; then
    if ! output="$(xcrun notarytool submit "$artifact" --keychain-profile "$KEYCHAIN_PROFILE" --wait --verbose 2>&1)"; then
      echo "$output" >&2
      return 1
    fi
  else
    if ! output="$(xcrun notarytool submit "$artifact" --keychain-profile "$KEYCHAIN_PROFILE" --wait 2>&1)"; then
      echo "$output" >&2
      return 1
    fi
  fi

  echo "$output"

  if printf '%s\n' "$output" | grep -q "status: Accepted"; then
    return 0
  fi

  if printf '%s\n' "$output" | grep -q "status: Invalid"; then
    local submission_id
    submission_id="$(printf '%s\n' "$output" | sed -n 's/.*id:[[:space:]]*\([a-f0-9-]\{8,\}\).*/\1/p' | head -n 1)"
    if [[ -n "$submission_id" ]]; then
      echo "Fetching rejection log for $submission_id" >&2
      xcrun notarytool log "$submission_id" --keychain-profile "$KEYCHAIN_PROFILE" || true
    fi
    return 1
  fi

  return 0
}

staple_and_validate() {
  local artifact="$1"
  local label="$2"

  if [[ "$NO_STAPLE" -eq 1 ]]; then
    echo "==> Skipping stapling for $label"
    return
  fi

  echo "==> Stapling $label"
  xcrun stapler staple "$artifact"

  echo "==> Validating stapled ticket for $label"
  xcrun stapler validate "$artifact" || true
}

require_command xcrun
require_command ditto

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [[ "$NOTARIZE_APP" -eq 1 ]]; then
  if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Error: app bundle not found: $APP_BUNDLE" >&2
    exit 1
  fi

  APP_ZIP="$DIST_DIR/$APP_NAME.zip"
  rm -f "$APP_ZIP"
  echo "==> Creating ZIP for app submission"
  ditto -c -k --keepParent "$APP_BUNDLE" "$APP_ZIP"

  submit_and_wait "$APP_ZIP" "$APP_NAME.app"
  staple_and_validate "$APP_BUNDLE" "$APP_NAME.app"
  rm -f "$APP_ZIP"
fi

if [[ "$NOTARIZE_DMG" -eq 1 ]]; then
  if [[ ! -f "$DMG_PATH" ]]; then
    echo "Error: DMG not found: $DMG_PATH" >&2
    exit 1
  fi

  submit_and_wait "$DMG_PATH" "$DMG_NAME"
  staple_and_validate "$DMG_PATH" "$DMG_NAME"
fi

echo "Notarization complete."
