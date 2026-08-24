#!/bin/bash
# Fails if PowerTop shows a content window at launch (the "flash").
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/PowerTop.app"
BIN="$APP/Contents/MacOS/PowerTop"

cd "$ROOT"
bash build.sh >/tmp/powertop-smoke-build.log 2>&1

killall PowerTop >/dev/null 2>&1 || true
sleep 0.2

set +e
"$BIN" --smoke-launch >/tmp/powertop-smoke-launch.log 2>&1
status=$?
set -e

cat /tmp/powertop-smoke-launch.log >&2 || true
exit "$status"
