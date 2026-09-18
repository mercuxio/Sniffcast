#!/usr/bin/env bash
# Run the SniffcastTests unit tests.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
xcodegen generate --quiet
xcodebuild -project Sniffcast.xcodeproj -scheme Sniffcast -derivedDataPath build \
  -destination 'platform=macOS' test 2>&1 \
  | grep -E "error:|warning:|✘|✔ Test run|Test run with|TEST (SUCCEEDED|FAILED)|recorded an issue" | grep -v appintentsmetadataprocessor || true
