#!/bin/bash
# Makes the download zip for GitHub Releases: build/Notchpad-<version>.zip
# The app is signed ad hoc, so it carries no developer certificate (no name, no Team ID),
# and the script stops if the app contains a home-folder path or this Mac's Team ID.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=Release SIGN_IDENTITY=- scripts/build.sh
APP=build/Build/Products/Release/Notchpad.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

OUT=build/release
rm -rf "$OUT" && mkdir -p "$OUT"
cp -R "$APP" "$OUT/"
# Debug symbols hold the build machine's source paths (/Users/<name>/...): strip them, then sign.
strip -S -x "$OUT/Notchpad.app/Contents/MacOS/Notchpad" 2>/dev/null
codesign --force --deep --sign - --options runtime --entitlements Notchpad/Notchpad.entitlements "$OUT/Notchpad.app"

# Security check: Hardened Runtime must be on.
# (Text in a variable: `grep -q` in a pipe can end the pipe early, which `pipefail` treats as an error.)
FLAGS=$(codesign -dv "$OUT/Notchpad.app" 2>&1 | sed -n 's/.*flags=\([^ ]*\).*/\1/p')
if [[ "$FLAGS" != *runtime* ]]; then
  echo "STOP: Hardened Runtime is not on ($FLAGS)"; exit 1
fi

# Privacy checks.
if grep -rl --binary-files=text "/Users/" "$OUT/Notchpad.app" >/dev/null; then
  echo "STOP: the app contains a /Users/ path:"; grep -rl --binary-files=text "/Users/" "$OUT/Notchpad.app"; exit 1
fi
TEAM=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' || true)
if [ -n "$TEAM" ] && grep -rl --binary-files=text "$TEAM" "$OUT/Notchpad.app" >/dev/null; then
  echo "STOP: the app contains this Mac's Team ID"; exit 1
fi
if grep -rl --binary-files=text -e "@gmail" -e "@icloud" "$OUT/Notchpad.app" >/dev/null; then
  echo "STOP: the app contains an email address"; exit 1
fi
# Read the signature first: piping straight into grep -q can end in SIGPIPE and wrongly pass.
SIGNATURE=$(codesign -dv "$OUT/Notchpad.app" 2>&1)
if grep -q "TeamIdentifier=[A-Z0-9]" <<<"$SIGNATURE"; then
  echo "STOP: the app is signed with a team certificate"; exit 1
fi

ZIP="build/Notchpad-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$OUT/Notchpad.app" "$ZIP"
echo "Made $ZIP"
shasum -a 256 "$ZIP"
