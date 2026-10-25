#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift package dump-package > /dev/null
swift build
swift build -c release
printf '%s\n' 'Scaffold validation passed: manifest and empty-module Debug/Release builds only.' 'No inference, UCI, tests, or physical-device validation exists yet.'
