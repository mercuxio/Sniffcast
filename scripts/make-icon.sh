#!/usr/bin/env bash
# Regenerates Sniffcast/Resources/AppIcon.icns from Tools/GenerateIcon.swift.
# The .icns is committed, so a normal build doesn't need this; run it after
# changing the generator.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
WORK="$(mktemp -d)"
trap 'rm -r "$WORK"' EXIT
swift "$ROOT/Tools/GenerateIcon.swift" "$WORK/AppIcon.iconset"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$ROOT/Sniffcast/Resources/AppIcon.icns"
echo "Wrote $ROOT/Sniffcast/Resources/AppIcon.icns"
