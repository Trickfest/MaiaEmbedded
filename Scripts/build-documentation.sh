#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
swift package dump-symbol-graph
mkdir -p .build/docs
for module in MaiaEmbedded MaiaUCI; do
    mkdir -p ".build/docs/$module-symbols"
    cp ".build/out/symbolgraph/$module.symbols.json" ".build/docs/$module-symbols/"
    xcrun docc convert "Sources/$module/$module.docc" \
        --additional-symbol-graph-dir ".build/docs/$module-symbols" \
        --fallback-display-name "$module" --fallback-bundle-identifier "org.maiaembedded.$module" \
        --fallback-bundle-version "${MAIA_DOCUMENTATION_VERSION:-1.0.0}" --output-path ".build/docs/$module.doccarchive" --warnings-as-errors
done
