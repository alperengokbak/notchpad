#!/bin/bash
# After `scripts/release.sh` and `gh release create`: points the Homebrew cask at the new release.
# Expects the tap next to this repo (../homebrew-notchpad). Commits there; pushing stays a separate step.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(awk -F'"' '/CFBundleShortVersionString/{print $2; exit}' project.yml)
ZIP="build/Notchpad-$VERSION.zip"
CASK="../homebrew-notchpad/Casks/notchpad.rb"
[ -f "$ZIP" ] || { echo "No $ZIP. Run scripts/release.sh first."; exit 1; }
[ -f "$CASK" ] || { echo "No $CASK. Clone github.com/alperengokbak/homebrew-notchpad next to this repo."; exit 1; }
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
brew style "$CASK" >/dev/null
git -C ../homebrew-notchpad commit -qam "Notchpad $VERSION cask"
echo "Cask now at $VERSION ($SHA). Push with: git -C ../homebrew-notchpad push"
