#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

dotnet publish "$ROOT_DIR/DuckGame/DuckGame.Net8.csproj" \
  -c Release \
  -r osx-arm64 \
  --self-contained true \
  /p:PublishSingleFile=false
