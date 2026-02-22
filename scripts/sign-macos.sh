#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/macos"

APP_NAME="DuckGameRebuilt"
APP_PATH=""
IDENTITY=""
ENTITLEMENTS="$ROOT_DIR/scripts/DuckGameRebuilt.entitlements"
CONCURRENCY="10"
VERBOSE=0

print_help() {
  cat <<'EOF'
Usage: ./scripts/sign-macos.sh [options]

Signs a macOS app bundle with hardened runtime. Native binaries are signed in
parallel, then bundle wrappers and the app are signed.

Options:
  --identity IDENTITY     Code signing identity (required)
  --app-name NAME         App bundle name in dist/macos (default: DuckGameRebuilt)
  --app-path PATH         Explicit path to .app bundle
  --entitlements PATH     Entitlements file (default: scripts/DuckGameRebuilt.entitlements)
  --concurrency N         Parallel codesign jobs (default: 10)
  --verbose               Verbose output
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity)
      IDENTITY="${2:-}"
      shift
      ;;
    --app-name)
      APP_NAME="${2:-}"
      shift
      ;;
    --app-path)
      APP_PATH="${2:-}"
      shift
      ;;
    --entitlements)
      ENTITLEMENTS="${2:-}"
      shift
      ;;
    --concurrency)
      CONCURRENCY="${2:-}"
      shift
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

if [[ -z "$IDENTITY" ]]; then
  echo "Error: --identity is required." >&2
  echo "Available identities:" >&2
  security find-identity -v -p codesigning || true
  exit 1
fi

if ! [[ "$CONCURRENCY" =~ ^[0-9]+$ ]] || [[ "$CONCURRENCY" -lt 1 ]]; then
  echo "Error: --concurrency must be a positive integer." >&2
  exit 1
fi

if [[ -z "$APP_PATH" ]]; then
  APP_PATH="$DIST_DIR/$APP_NAME.app"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app bundle not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "Error: entitlements file not found: $ENTITLEMENTS" >&2
  exit 1
fi

CONTENTS_DIR="$APP_PATH/Contents"

TARGETS_FILE="$(mktemp)"
BUNDLES_FILE="$(mktemp)"
trap 'rm -f "$TARGETS_FILE" "$BUNDLES_FILE"' EXIT

while IFS= read -r -d '' file_path; do
  if file -b "$file_path" | grep -q "Mach-O"; then
    printf '%s\0' "$file_path" >> "$TARGETS_FILE"
  fi
done < <(find "$CONTENTS_DIR" -type f -print0)

NATIVE_COUNT="$(tr -cd '\0' < "$TARGETS_FILE" | wc -c | tr -d ' ')"

if [[ "$NATIVE_COUNT" -gt 0 ]]; then
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "Signing $NATIVE_COUNT native files with concurrency=$CONCURRENCY"
  else
    echo "Signing $NATIVE_COUNT native files in parallel"
  fi

  export IDENTITY ENTITLEMENTS VERBOSE
  xargs -0 -n1 -P "$CONCURRENCY" bash -c '
    target="$0"
    if [[ "${VERBOSE:-0}" -eq 1 ]]; then
      echo "  [sign] $target"
    fi
    codesign --force --sign "$IDENTITY" --options runtime --timestamp --entitlements "$ENTITLEMENTS" "$target"
  ' < "$TARGETS_FILE"
fi

find "$CONTENTS_DIR" -type d \( -name "*.bundle" -o -name "*.framework" \) -print |
  awk '{ depth=gsub(/\//,"/"); print depth "\t" $0 }' |
  sort -rn |
  cut -f2- > "$BUNDLES_FILE"

while IFS= read -r bundle_path; do
  [[ -z "$bundle_path" ]] && continue
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "  [bundle] $bundle_path"
  fi
  codesign --force --sign "$IDENTITY" --options runtime --timestamp --entitlements "$ENTITLEMENTS" "$bundle_path"
done < "$BUNDLES_FILE"

echo "Signing app bundle wrapper"
codesign --force --sign "$IDENTITY" --options runtime --timestamp --entitlements "$ENTITLEMENTS" "$APP_PATH"

echo "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Signed: $APP_PATH"
