#!/usr/bin/env bash
# Build Sniffcast (Debug by default; pass "Release" as $1 for a release build).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
xcodegen generate --quiet
xcodebuild -project Sniffcast.xcodeproj -scheme Sniffcast -configuration "${1:-Debug}" \
  -derivedDataPath build -destination 'platform=macOS' build 2>&1 \
  | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | grep -v "appintentsmetadataprocessor" || true
