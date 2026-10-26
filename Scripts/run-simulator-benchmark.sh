#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
simulator_udid="${1:?Usage: run-simulator-benchmark.sh SIMULATOR_UDID [duration-seconds]}"
simulator_duration="${2:-30}"
[[ -f Resources/Models/maia3-79m.onnx ]] || {
    printf '%s\n' 'Run Scripts/download-model.sh first.' >&2; exit 1;
}
xcodebuild -project Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj \
    -scheme MaiaBenchmark -configuration Release -destination "id=$simulator_udid" \
    -derivedDataPath .build/xcode-maia -clonedSourcePackagesDirPath .build/xcode-maia/SourcePackages \
    CODE_SIGNING_ALLOWED=NO build
# Boot explicitly before invoking this script. No XCTest or UI automation is used.
xcrun simctl install "$simulator_udid" .build/xcode-maia/Build/Products/Release-iphonesimulator/MaiaBenchmark.app
xcrun simctl launch --terminate-running-process "$simulator_udid" \
    org.maiaembedded.experiment.MaiaBenchmark --autorun --iterations 100 --duration "$simulator_duration"
printf '%s\n' 'After completion, the app writes Documents/maia-benchmark.json in its simulator data container.'
