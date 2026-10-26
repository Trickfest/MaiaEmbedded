#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
model_path="Resources/Models/maia3-79m.onnx"
expected_sha="3454b03ae78baa64a87b345fdb1a457265d912caec531039b074f07eda0d8010"
verify() {
    [[ -f "$1" && "$(stat -f %z "$1")" == 316034244 ]] &&
        [[ "$(shasum -a 256 "$1" | cut -d ' ' -f 1)" == "$expected_sha" ]]
}
if verify "$model_path"; then
    printf '%s\n' 'Pinned 79M ONNX model is already verified.'
    exit 0
fi
mkdir -p Resources/Models
model_tmp="$(mktemp Resources/Models/.download.XXXXXX)"
trap 'rm -f "$model_tmp"' EXIT
curl --fail --location --retry 2 --show-error \
    'https://media.githubusercontent.com/media/Dash1971/maia-chess-android/5f6743eed5491d2e8413fe0dfd1f8ef612d0aa84/assets/models/maia3-79m.onnx' \
    --output "$model_tmp"
verify "$model_tmp" || { printf '%s\n' 'Model verification failed.' >&2; exit 1; }
mv "$model_tmp" "$model_path"
printf '%s\n' 'Pinned 79M ONNX model downloaded and verified.'
