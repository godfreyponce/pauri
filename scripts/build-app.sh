#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
IDENTITY="Pauri Self-Signed"
RELEASE=
if [ "${1:-}" = --release ]; then
  RELEASE="${2:?usage: scripts/build-app.sh [--release X.Y.Z]}"
fi

swift build -c release --product Pauri
BIN="$(swift build -c release --show-bin-path)/Pauri"
APP=build/Pauri.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Pauri"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [ -n "$RELEASE" ]; then
  /usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $RELEASE" \
    -c "Set :CFBundleVersion $RELEASE" \
    -c "Add :PauriChecksForUpdates bool YES" \
    "$APP/Contents/Info.plist"
fi
mkdir -p "$APP/Contents/Resources"
cp Support/OAI_OpenAI-Blossom_Black.svg Support/OAI_OpenAI-Blossom_White.svg "$APP/Contents/Resources/"
FW="$APP/Contents/Frameworks/Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
ditto "$(swift build -c release --show-bin-path)/Sparkle.framework" "$FW"
# Pauri is not sandboxed, so Sparkle's XPC services go unused.
rm -rf "$FW/Versions/B/XPCServices" "$FW/XPCServices"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Pauri"
# No -v: macOS never counts a self-signed certificate as valid, so -v would hide it.
if security find-identity -p codesigning | grep -qF "\"$IDENTITY\""; then
  SIGN="$IDENTITY"
  MESSAGE="Signed with the $IDENTITY certificate."
elif [ -n "$RELEASE" ]; then
  echo "Release builds need the $IDENTITY certificate. Restore it: docs/superpowers/plans/2026-11-16-issue-27.md (\"Owner's one-time steps\")." >&2
  exit 1
else
  SIGN=-
  MESSAGE="Signed ad-hoc: no $IDENTITY certificate in the keychain. macOS forgets Pauri's permissions after each ad-hoc rebuild."
fi
# Inside-out, no --deep, per sparkle-project.org/documentation/sandboxing.
for PART in "$FW/Versions/B/Autoupdate" "$FW/Versions/B/Updater.app" "$FW" "$APP"; do
  codesign --force --sign "$SIGN" "$PART"
done
echo "$MESSAGE"
echo "$APP"
