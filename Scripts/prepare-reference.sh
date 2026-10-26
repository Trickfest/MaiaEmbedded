#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
Scripts/download-model.sh
mkdir -p .build/upstream .build/checkpoints
upstream_path=".build/upstream/maia3"
upstream_sha="1e13597c42d4858b7cfd7cfdae01e297263364b2"
if [[ ! -d "$upstream_path/.git" ]]; then
    git clone --no-checkout https://github.com/CSSLab/maia3.git "$upstream_path"
fi
[[ "$(git -C "$upstream_path" remote get-url origin)" == 'https://github.com/CSSLab/maia3.git' ]] || {
    printf '%s\n' 'Unexpected upstream origin; refusing to use it.' >&2; exit 1;
}
[[ -z "$(git -C "$upstream_path" status --porcelain)" ]] || {
    printf '%s\n' 'Upstream checkout has local changes; refusing to replace them.' >&2; exit 1;
}
git -C "$upstream_path" checkout --detach "$upstream_sha"
checkpoint_path=".build/checkpoints/maia3-79m.pt"
checkpoint_sha="3fc6181d5db789b45a15305732148757ae74efa3e0028e81ba335b462dac45c2"
if [[ ! -f "$checkpoint_path" ]] || [[ "$(shasum -a 256 "$checkpoint_path" | cut -d ' ' -f 1)" != "$checkpoint_sha" ]]; then
    checkpoint_tmp="$(mktemp .build/checkpoints/.download.XXXXXX)"
    trap 'rm -f "$checkpoint_tmp"' EXIT
    curl --fail --location --retry 2 --show-error \
        'https://huggingface.co/UofTCSSLab/Maia3-79M/resolve/a107d6ceb7b298cb04ae1da4edffe2939858b894/maia3-79m.pt' \
        --output "$checkpoint_tmp"
    [[ "$(stat -f %z "$checkpoint_tmp")" == 315651851 && \
       "$(shasum -a 256 "$checkpoint_tmp" | cut -d ' ' -f 1)" == "$checkpoint_sha" ]] || {
        printf '%s\n' 'Checkpoint verification failed.' >&2; exit 1;
    }
    mv "$checkpoint_tmp" "$checkpoint_path"
fi
reference_python="${MAIA_REFERENCE_PYTHON:-python3.13}"
if [[ ! -x .build/reference-venv/bin/python ]]; then
    "$reference_python" -m venv .build/reference-venv
fi
.build/reference-venv/bin/python -m pip install -r Tools/requirements-reference.txt
.build/reference-venv/bin/python Tools/generate_reference.py \
    --upstream "$upstream_path" --checkpoint "$checkpoint_path" \
    --onnx Resources/Models/maia3-79m.onnx \
    --output Sources/MaiaBenchmarkSupport/Resources/reference.json
