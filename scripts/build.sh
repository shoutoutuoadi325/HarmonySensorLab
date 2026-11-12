#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVECO_ROOT="${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app/Contents}"
export NODE_HOME="$DEVECO_ROOT/tools/node"
export JAVA_HOME="$DEVECO_ROOT/jbr/Contents/Home"
export DEVECO_SDK_HOME="$DEVECO_ROOT/sdk"
product=default
mode=debug
if [ "$#" -gt 0 ]; then product="$1"; fi
if [ "$#" -gt 1 ]; then mode="$2"; fi
if [ "$mode" = release ] && [ "${HARMONY_UNSIGNED_PREVIEW:-0}" != 1 ]; then
  python3 scripts/preflight-release-privacy.py
fi
if [ "${3:-hap}" = app ]; then
  exec "$DEVECO_ROOT/tools/hvigor/bin/hvigorw" --mode project -p product="$product" -p buildMode="$mode" assembleApp --no-daemon
fi
exec "$DEVECO_ROOT/tools/hvigor/bin/hvigorw" --mode module -p product="$product" -p module=entry@"$product" -p buildMode="$mode" assembleHap --no-daemon
