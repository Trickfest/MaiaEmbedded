#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
device_id="${1:?Usage: run-device-benchmark.sh DEVICE_IDENTIFIER [duration-seconds]}"
device_duration="${2:-1200}"
device_mode="${3:---autorun}"
case "$device_mode" in
    --autorun) launch_arguments=(--autorun --iterations 100 --duration "$device_duration") ;;
    --package-checks) launch_arguments=(--package-checks) ;;
    *) printf '%s\n' 'Mode must be --autorun or --package-checks.' >&2; exit 2 ;;
esac
[[ -f Examples/MaiaBenchmark/Configurations/Signing.local.xcconfig ]] || {
    printf '%s\n' 'Create the ignored local signing configuration described in Examples/MaiaBenchmark/README.md first.' >&2
    exit 1
}
[[ -f Resources/Models/maia3-79m.onnx ]] || {
    printf '%s\n' 'Run Scripts/download-model.sh first.' >&2; exit 1;
}
# No provisioning-account updates or UI-test runner. The device must be unlocked
# and trusted, with signing already configured by its owner.
xcodebuild -project Examples/MaiaBenchmark/MaiaBenchmark.xcodeproj \
    -scheme MaiaBenchmark -configuration Release -destination "id=$device_id" \
    -derivedDataPath .build/xcode-device-signed \
    -clonedSourcePackagesDirPath .build/xcode-device-signed/SourcePackages build
app_path=".build/xcode-device-signed/Build/Products/Release-iphoneos/MaiaBenchmark.app"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_path/Info.plist")"
xcrun devicectl device install app --device "$device_id" "$app_path"
xcrun devicectl device process launch --device "$device_id" --terminate-existing \
    "$bundle_id" -- "${launch_arguments[@]}"
printf '%s\n' 'Keep the app foreground and the device unlocked until completion, then export its JSON report.'
