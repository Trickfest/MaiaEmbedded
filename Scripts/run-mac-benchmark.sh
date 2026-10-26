#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
# Model preparation is explicit; running the benchmark never downloads assets.
[[ -f Resources/Models/maia3-79m.onnx ]] || {
    printf '%s\n' 'Run Scripts/download-model.sh first.' >&2; exit 1;
}
swift build -c release
.build/release/maia-benchmark --model Resources/Models/maia3-79m.onnx \
    --output .build/results/mac-benchmark.json --duration "${1:-1200}" --iterations 100
