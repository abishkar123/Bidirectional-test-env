#!/usr/bin/env bash
# Validates every tenants/*.json manifest against tenants/schema/tenant-manifest.schema.json.
# Requires: node + npx (ajv-cli resolved on demand, no repo dependency added).
set -euo pipefail

cd "$(dirname "$0")"

shopt -s nullglob
manifests=(*.json)
shopt -u nullglob

if [ ${#manifests[@]} -eq 0 ]; then
  echo "No tenant manifests found in tenants/."
  exit 1
fi

for manifest in "${manifests[@]}"; do
  echo "Validating $manifest ..."
  npx --yes ajv-cli validate -s schema/tenant-manifest.schema.json -d "$manifest" --strict=false
done

echo "All tenant manifests valid."
