#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

stop() {
  echo "release: $1" >&2
  exit 1
}

VERSION="${1:-}"
DRY_RUN="${2:-}"
if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || [ $# -gt 2 ] ||
  { [ -n "$DRY_RUN" ] && [ "$DRY_RUN" != --dry-run ]; }; then
  stop "usage: scripts/release.sh X.Y.Z [--dry-run]"
fi
TAG="v$VERSION"

[ -z "$(git status --porcelain)" ] || stop "The working tree has changes. Commit or remove them first."
git fetch -q --tags origin
! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || stop "Tag $TAG already exists."
HIGHEST="$(git tag -l 'v[0-9]*' | sed 's/^v//' | sort -V | tail -1)"
if [ -n "$HIGHEST" ] && [ "$(printf '%s\n%s\n' "$HIGHEST" "$VERSION" | sort -V | tail -1)" != "$VERSION" ]; then
  stop "$VERSION is not newer than v$HIGHEST. Sparkle would not offer it."
fi
if [ -z "$DRY_RUN" ]; then
  git fetch -q origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || stop "HEAD is not origin/main. Release from main after you push."
fi

./scripts/build-app.sh --release "$VERSION"

SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin
KEY="$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null)" ||
  stop "No Sparkle update key in the keychain. Restore it: docs/superpowers/plans/2026-11-16-issue-28.md (\"Owner's one-time steps\")."
[ "$KEY" = "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' Support/Info.plist)" ] ||
  stop "The keychain's update key does not match SUPublicEDKey in Support/Info.plist. Installed copies would refuse this update."

OUT=build/release
rm -rf "$OUT"
mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent build/Pauri.app "$OUT/Pauri.zip"
"$SPARKLE_BIN/generate_appcast" --download-url-prefix "https://github.com/godfreyponce/pauri/releases/download/$TAG/" "$OUT"

if [ -n "$DRY_RUN" ]; then
  echo "Dry run: nothing published."
  echo "$OUT/Pauri.zip"
  echo "$OUT/appcast.xml"
  exit 0
fi

gh release create "$TAG" "$OUT/Pauri.zip" "$OUT/appcast.xml" --target "$(git rev-parse HEAD)" --title "$TAG" --notes "$TAG"
git fetch -q origin tag "$TAG"
echo "Released $TAG: https://github.com/godfreyponce/pauri/releases/tag/$TAG"
