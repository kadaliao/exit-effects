#!/bin/bash
# Downloads the Exit release that the checks run against (the version in .exit-version)
# into build/Exit.app. Set EXIT_BIN instead to use your own build.
set -euo pipefail
cd "$(dirname "$0")/.."
v=$(tr -d '[:space:]' < .exit-version)
mkdir -p build
rm -rf build/Exit.app
curl -fsSL --retry 3 -o "build/Exit-$v.zip" "https://github.com/kadaliao/exit/releases/download/v$v/Exit-$v.zip"
ditto -x -k "build/Exit-$v.zip" build/
build/Exit.app/Contents/MacOS/Exit --version
