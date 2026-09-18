#!/usr/bin/env bash
# Builds a Release Sniffcast.app and zips it for a GitHub release.
#
# The signature is ad-hoc (`CODE_SIGN_IDENTITY: "-"` in project.yml). That is
# enough for an app you build and launch yourself, and not enough for
# distribution: a downloaded copy is quarantined, which the README's install
# note covers. It also means macOS identifies the app by its code hash, so a
# new build is a new app to Location Services and asks for permission again.
#
# `ditto -c -k --keepParent` rather than `zip`: ditto keeps the bundle's
# extended attributes and symlinks intact, which `zip -r` does not.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

./scripts/build.sh Release

APP="$ROOT/build/Build/Products/Release/Sniffcast.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP="$ROOT/build/Sniffcast-$VERSION.zip"

codesign --verify --strict "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Built $APP"
echo "Packaged $ZIP ($(lipo -archs "$APP/Contents/MacOS/Sniffcast"))"
