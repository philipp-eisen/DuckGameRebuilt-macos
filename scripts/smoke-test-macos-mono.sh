#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_SECONDS="${1:-20}"
LOG_PATH="$ROOT_DIR/run.log"

if ! [[ "$RUNTIME_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "Runtime must be an integer number of seconds" >&2
  exit 1
fi

cd "$ROOT_DIR/bin"

mono ./DuckGame.exe -nointro -nomods -nosteam > "$LOG_PATH" 2>&1 &
GAME_PID=$!

sleep "$RUNTIME_SECONDS"

if ! kill -0 "$GAME_PID" 2>/dev/null; then
  wait "$GAME_PID"
  echo "DuckGame exited before smoke-test timeout." >&2
  exit 1
fi

kill "$GAME_PID"
wait "$GAME_PID" || true

echo "Smoke test passed (${RUNTIME_SECONDS}s)."
echo "Log: $LOG_PATH"
