#!/bin/bash
# Builds Notchpad. Signs with your "Apple Development" certificate if you have one
# (so macOS keeps permissions between builds), otherwise signs ad hoc.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
IDENTITY=$(security find-identity -v -p codesigning | awk '/"Apple Development/{print $2; exit}')
IDENTITY=${IDENTITY:--}
xcodebuild -project Notchpad.xcodeproj -scheme Notchpad -configuration "${CONFIG:-Debug}" \
  -derivedDataPath build CODE_SIGN_IDENTITY="$IDENTITY" build > build/xcodebuild.log 2>&1 \
  || { grep -E " error:" build/xcodebuild.log | head -20; echo "** BUILD FAILED ** (see build/xcodebuild.log)"; exit 1; }
grep -E "\*\* BUILD" build/xcodebuild.log | tail -1
