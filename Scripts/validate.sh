#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
swift package dump-package > /dev/null
swift test
swift build -c release
printf '%s\n' 'Non-UI package validation passed. Real-model/device evidence is separate.'
