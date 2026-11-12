#!/usr/bin/env python3
"""Verify the current signed Release packages independently of the baseline Debug artifacts."""
import argparse
import json
from release_signing import ROOT, PRODUCTS, FIRST_RELEASE_PRODUCTS, verify_hap, verify_app_container

parser = argparse.ArgumentParser()
parser.add_argument("--products", nargs="+", choices=PRODUCTS, default=list(FIRST_RELEASE_PRODUCTS),
                    help="Products to verify; defaults to the approved first release without TV.")
args = parser.parse_args()
if len(args.products) != len(set(args.products)):
    parser.error("Each product must be selected only once.")

results = []
for product in args.products:
    hap = ROOT / f"dist/packages/sensor-{product}-release-signed.hap"
    app = ROOT / f"dist/packages/sensor-{product}-release-signed.app"
    results.append({"file": str(hap.relative_to(ROOT)), **verify_hap(hap, product)})
    results.append({"file": str(app.relative_to(ROOT)), **verify_app_container(app, hap, product)})
print(json.dumps({"products": args.products, "packages": results, "note": "Release signing and payloads verified; store review remains separate."},
                 ensure_ascii=False, indent=2))
