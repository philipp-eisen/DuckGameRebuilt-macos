#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/macos"

APP_NAME="DuckGameRebuilt"
BUNDLE_ID="com.duckgamerebuilt.app"
CONFIGURATION="Release"
ICON_SOURCE="DuckGame/DuckGame.ico"
VERSION=""
VOLUME_NAME="DuckGameRebuilt"
DMG_NAME=""
SIGN_IDENTITY=""
SIGN_CONCURRENCY="10"
ENTITLEMENTS="$ROOT_DIR/scripts/DuckGameRebuilt.entitlements"

SKIP_BUILD=0
NO_SIGN=0
CREATE_DMG=0

print_help() {
  cat <<'EOF'
Usage: ./scripts/package-macos.sh [options]

Builds a Mono-based macOS app bundle and optionally packages a DMG.

Options:
  --configuration CONFIG   Build configuration (default: Release)
  --skip-build             Skip build step (reuse existing ./bin output)
  --no-sign                Skip code signing
  --sign-identity ID       Developer ID identity for signing
  --sign-concurrency N     Parallel signing jobs (default: 10)
  --entitlements PATH      Entitlements file (default: scripts/DuckGameRebuilt.entitlements)
  --app-name NAME          App bundle name (default: DuckGameRebuilt)
  --bundle-id ID           CFBundleIdentifier (default: com.duckgamerebuilt.app)
  --version VERSION        Version string (default: git short hash)
  --icon-source PATH       Icon source file (default: DuckGame/DuckGame.ico)
  --dmg                    Also create a DMG
  --volume-name NAME       DMG volume name (default: DuckGameRebuilt)
  --dmg-name NAME          DMG file name (default: <app>-macos-mono-<arch>.dmg)
  -h, --help               Show this help
EOF
}

resolve_path() {
  local path_value="$1"
  if [[ "$path_value" = /* ]]; then
    printf '%s' "$path_value"
  else
    printf '%s/%s' "$ROOT_DIR" "$path_value"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="${2:-}"
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --no-sign)
      NO_SIGN=1
      ;;
    --sign-identity)
      SIGN_IDENTITY="${2:-}"
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
    --dmg)
      CREATE_DMG=1
      ;;
    --volume-name)
      VOLUME_NAME="${2:-}"
      shift
      ;;
    --dmg-name)
      DMG_NAME="${2:-}"
      shift
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

if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
  VERSION="${VERSION:-dev}"
fi

ICON_SOURCE="$(resolve_path "$ICON_SOURCE")"
ENTITLEMENTS="$(resolve_path "$ENTITLEMENTS")"

HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" == "x86_64" ]]; then
  HOST_ARCH="x64"
elif [[ "$HOST_ARCH" == "arm64" ]]; then
  HOST_ARCH="arm64"
fi

if [[ -z "$DMG_NAME" ]]; then
  DMG_NAME="${APP_NAME}-macos-mono-${HOST_ARCH}.dmg"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> Building Mono macOS output ($CONFIGURATION)"
  "$ROOT_DIR/scripts/build-macos.sh" "$CONFIGURATION"
fi

if [[ ! -f "$ROOT_DIR/bin/DuckGame.exe" ]]; then
  echo "Error: missing build output at $ROOT_DIR/bin/DuckGame.exe" >&2
  exit 1
fi

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
GAME_DIR="$RESOURCES_DIR/game"
PLIST_PATH="$APP_BUNDLE/Contents/Info.plist"
LAUNCHER_PATH="$MACOS_DIR/DuckGame"

echo "==> Creating app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$GAME_DIR"
cp -R "$ROOT_DIR/bin/." "$GAME_DIR/"

cat > "$LAUNCHER_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$APP_DIR/Resources/game"
LOG_DIR="${HOME}/Library/Logs/DuckGameRebuilt"
LAUNCH_LOG="$LOG_DIR/launcher.log"

log_message() {
  mkdir -p "$LOG_DIR" >/dev/null 2>&1 || true
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LAUNCH_LOG"
}

show_error() {
  local message="$1"
  log_message "$message"
  echo "$message" >&2
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display alert \"DuckGameRebuilt\" message \"$message\" as critical" >/dev/null 2>&1 || true
  fi
}

resolve_mono() {
  if [[ -n "${MONO_COMMAND:-}" ]]; then
    if [[ -x "$MONO_COMMAND" ]]; then
      printf '%s' "$MONO_COMMAND"
      return 0
    fi
    if command -v "$MONO_COMMAND" >/dev/null 2>&1; then
      command -v "$MONO_COMMAND"
      return 0
    fi
  fi

  if command -v mono >/dev/null 2>&1; then
    command -v mono
    return 0
  fi

  if [[ -x "/opt/homebrew/bin/mono" ]]; then
    printf '%s' "/opt/homebrew/bin/mono"
    return 0
  fi

  if [[ -x "/usr/local/bin/mono" ]]; then
    printf '%s' "/usr/local/bin/mono"
    return 0
  fi

  if [[ -x "/opt/homebrew/opt/mono/bin/mono" ]]; then
    printf '%s' "/opt/homebrew/opt/mono/bin/mono"
    return 0
  fi

  if [[ -x "/usr/local/opt/mono/bin/mono" ]]; then
    printf '%s' "/usr/local/opt/mono/bin/mono"
    return 0
  fi

  return 1
}

if ! MONO_CMD="$(resolve_mono)"; then
  show_error "Mono runtime not found. Install with: brew install mono"
  exit 1
fi

export DYLD_FALLBACK_LIBRARY_PATH="$GAME_DIR:${DYLD_FALLBACK_LIBRARY_PATH:-}"
export MONO_PATH="$GAME_DIR/OSX-Linux-x64:${MONO_PATH:-}"
export DGR_SKIP_STEAMWORKS_COPY=1
cd "$GAME_DIR"
exec "$MONO_CMD" "./DuckGame.exe" "$@"
EOF
chmod +x "$LAUNCHER_PATH"

ICON_PLIST_BLOCK=""
if [[ -f "$ICON_SOURCE" ]] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  TMP_DIR="$(mktemp -d)"
  BASE_PNG="$TMP_DIR/base.png"
  ICONSET_DIR="$TMP_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"

  if sips -s format png "$ICON_SOURCE" --out "$BASE_PNG" >/dev/null 2>&1; then
    sips -z 1024 1024 "$BASE_PNG" --out "$BASE_PNG" >/dev/null 2>&1 || true
    for size in 16 32 128 256 512; do
      retina=$((size * 2))
      sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null 2>&1 || true
      sips -z "$retina" "$retina" "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null 2>&1 || true
    done
    if iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" >/dev/null 2>&1; then
      ICON_PLIST_BLOCK=$'  <key>CFBundleIconFile</key>\n  <string>AppIcon</string>'
    fi
  fi

  rm -rf "$TMP_DIR"
fi

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
${ICON_PLIST_BLOCK}
  <key>CFBundleExecutable</key>
  <string>DuckGame</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

if [[ "$NO_SIGN" -eq 0 ]]; then
  if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "==> Signing app with identity"
    "$ROOT_DIR/scripts/sign-macos.sh" \
      --identity "$SIGN_IDENTITY" \
      --app-path "$APP_BUNDLE" \
      --entitlements "$ENTITLEMENTS" \
      --concurrency "$SIGN_CONCURRENCY"
  else
    echo "==> Ad-hoc signing app for local development"
    codesign --force --deep --sign - "$APP_BUNDLE"
  fi
else
  echo "==> Skipping code signing"
fi

echo "Created app bundle: $APP_BUNDLE"

if [[ "$CREATE_DMG" -eq 1 ]]; then
  STAGE_DIR="$DIST_DIR/.dmg-staging"
  DMG_PATH="$DIST_DIR/$DMG_NAME"

  echo "==> Creating DMG: $DMG_PATH"
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR"
  cp -R "$APP_BUNDLE" "$STAGE_DIR/"
  ln -s /Applications "$STAGE_DIR/Applications"
  rm -f "$DMG_PATH"
  hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"
  rm -rf "$STAGE_DIR"

  if [[ "$NO_SIGN" -eq 0 && -n "$SIGN_IDENTITY" ]]; then
    echo "==> Signing DMG"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
  fi

  echo "Created DMG: $DMG_PATH"
fi
