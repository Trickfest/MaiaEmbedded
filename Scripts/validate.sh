#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f Resources/Models/maia3-79m.onnx ]] || {
    printf '%s\n' 'Run Scripts/download-model.sh before the complete local gate.' >&2; exit 1;
}
export MAIA_MODEL_PATH="$PWD/Resources/Models/maia3-79m.onnx"
mkdir -p .build/results
swift package dump-package > /dev/null
swift build
swift test
swift test -c release
# Exercise Swift command/output state under Thread Sanitizer. ORT is a prebuilt binary.
swift test --sanitize=thread
swift build -c release
Scripts/build-documentation.sh
release_bin="$(swift build -c release --show-bin-path)"
python3 Scripts/test-uci-cli.py "$release_bin/maia-uci" "$MAIA_MODEL_PATH"
"$release_bin/maia-smoke" --model "$MAIA_MODEL_PATH" --output .build/results/package-mac.json
"$release_bin/maia-soak" --model "$MAIA_MODEL_PATH" --iterations 200
if "$release_bin/maia-soak" --iterations 0 > /dev/null 2>&1; then
    printf '%s\n' 'maia-soak accepted zero iterations.' >&2; exit 1
fi
"$release_bin/maia-benchmark" --model "$MAIA_MODEL_PATH" --output .build/results/production-mac.json --duration 30
for destination in 'platform=macOS,arch=arm64' 'generic/platform=iOS Simulator' 'generic/platform=iOS'; do
    xcodebuild -project Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj -scheme MaiaBenchmark \
        -configuration Release -destination "$destination" -derivedDataPath .build/xcode-validation \
        -clonedSourcePackagesDirPath .build/xcode-validation/SourcePackages CODE_SIGNING_ALLOWED=NO build
done
# Match the explicit package-only SPI scheme without requiring the reference app's model.
for destination in 'platform=macOS,arch=arm64' 'generic/platform=iOS'; do
    xcodebuild -scheme MaiaUCI -configuration Release -destination "$destination" \
        -derivedDataPath .build/xcode-spi \
        -clonedSourcePackagesDirPath .build/xcode-spi/SourcePackages CODE_SIGNING_ALLOWED=NO build
done
for license in LICENSE ThirdParty/Maia3/LICENSE ThirdParty/ONNXRuntime/LICENSE; do
    [[ -f "$license" ]] || { printf 'Missing license: %s\n' "$license" >&2; exit 1; }
done
printf '%s\n' 'MaiaEmbedded local validation passed. Physical-device verification is a separate final gate.'
