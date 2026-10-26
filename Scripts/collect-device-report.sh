#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
device_id="${1:?Usage: collect-device-report.sh DEVICE_IDENTIFIER BUNDLE_IDENTIFIER OUTPUT_JSON}"
bundle_id="${2:?Supply the signed app bundle identifier.}"
report_path="${3:?Supply a local JSON destination (normally under .build/results).}"
mkdir -p "$(dirname "$report_path")"
xcrun devicectl device copy from --device "$device_id" \
    --domain-type appDataContainer --domain-identifier "$bundle_id" \
    --source Documents/maia-benchmark.json --destination "$report_path"
printf '%s\n' 'Verify report timestamps, completedAt and isSimulator=false before accepting this run.'
