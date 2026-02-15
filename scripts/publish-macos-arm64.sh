#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH_DIR="$ROOT_DIR/DuckGame/bin/Release/net8.0/osx-arm64/publish"
NATIVE_DIR="$ROOT_DIR/DuckGame/build/native/osx-arm64"

rm -rf "$PUBLISH_DIR"

dotnet publish "$ROOT_DIR/DuckGame/DuckGame.Net8.csproj" \
  -c Release \
  -r osx-arm64 \
  --self-contained true \
  /p:PublishSingleFile=false

if [ -f "$PUBLISH_DIR/Steamworks.NET.dll" ]; then
  dotnet run --project "$ROOT_DIR/scripts/SteamworksPatcher/SteamworksPatcher.csproj" -- "$PUBLISH_DIR/Steamworks.NET.dll"
fi

if compgen -G "$NATIVE_DIR/*.dylib" > /dev/null; then
  cp "$NATIVE_DIR"/*.dylib "$PUBLISH_DIR"/
fi

if [ -d "$ROOT_DIR/deps/Content" ]; then
  cp -R "$ROOT_DIR/deps/Content" "$PUBLISH_DIR/Content"
fi

if [ -d "$ROOT_DIR/deps/spriteatlas" ]; then
  cp -R "$ROOT_DIR/deps/spriteatlas" "$PUBLISH_DIR/spriteatlas"
fi

for asset in "lang.txt" "gamecontrollerdb.txt" "MonoFont.ttf"; do
  if [ -f "$ROOT_DIR/deps/$asset" ]; then
    cp "$ROOT_DIR/deps/$asset" "$PUBLISH_DIR/$asset"
  fi
done

if [ -d "$ROOT_DIR/deps/steam_api.bundle" ]; then
  cp -R "$ROOT_DIR/deps/steam_api.bundle" "$PUBLISH_DIR/steam_api.bundle"
elif [ -d "$ROOT_DIR/deps/OSX-Linux-x64/steam_api.bundle" ]; then
  cp -R "$ROOT_DIR/deps/OSX-Linux-x64/steam_api.bundle" "$PUBLISH_DIR/steam_api.bundle"
fi

if [ -f "$PUBLISH_DIR/steam_api.bundle/Contents/MacOS/libsteam_api.dylib" ]; then
  cp "$PUBLISH_DIR/steam_api.bundle/Contents/MacOS/libsteam_api.dylib" "$PUBLISH_DIR/steam_api64.dylib"
  cp "$PUBLISH_DIR/steam_api.bundle/Contents/MacOS/libsteam_api.dylib" "$PUBLISH_DIR/libsteam_api64.dylib"
fi

if [ -f "$PUBLISH_DIR/libSDL2-2.0.0.dylib" ]; then
  install_name_tool -id "@rpath/libSDL2-2.0.0.dylib" "$PUBLISH_DIR/libSDL2-2.0.0.dylib" || true
fi

for dylib in "$PUBLISH_DIR/libFNA3D.0.dylib" "$PUBLISH_DIR/libFAudio.0.dylib"; do
  if [ -f "$dylib" ]; then
    install_name_tool -change "/opt/homebrew/opt/sdl2/lib/libSDL2-2.0.0.dylib" "@rpath/libSDL2-2.0.0.dylib" "$dylib" || true
    install_name_tool -change "/opt/homebrew/lib/libSDL2-2.0.0.dylib" "@rpath/libSDL2-2.0.0.dylib" "$dylib" || true
  fi
done

for dylib in "$PUBLISH_DIR/libSDL2-2.0.0.dylib" "$PUBLISH_DIR/libFNA3D.0.dylib" "$PUBLISH_DIR/libFAudio.0.dylib"; do
  if [ -f "$dylib" ]; then
    codesign --force --sign - "$dylib" || true
  fi
done
