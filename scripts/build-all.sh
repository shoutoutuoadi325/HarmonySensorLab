#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist/packages reports
for product in default pc wearable tv; do
  for mode in debug release; do
    ./scripts/build.sh "$product" "$mode" > "reports/build-$mode-$product.log" 2>&1
    cp "entry/build/$product/outputs/$product/entry-$product-unsigned.hap" "dist/packages/sensor-$product-$mode-unsigned.hap"
  done
  ./scripts/build.sh "$product" release app > "reports/build-app-$product.log" 2>&1
  package=$(find "build/outputs/$product" -name '*.app' -type f -print -quit)
  if [ -n "$package" ]; then cp "$package" "dist/packages/sensor-$product-release-unsigned.app"; fi
done
node tests/host/run.cjs > reports/host-tests.log
node tests/host/ui-compiled.cjs > reports/ui-compiled-tests.log
python3 scripts/verify-packages.py --unsigned-only > reports/package-verification.json
