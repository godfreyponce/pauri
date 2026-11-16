#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
IDENTITY="Pauri Self-Signed"

swift build -c release --product Pauri
BIN="$(swift build -c release --show-bin-path)/Pauri"
APP=build/Pauri.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Pauri"
cp Support/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Support/OAI_OpenAI-Blossom_Black.svg Support/OAI_OpenAI-Blossom_White.svg "$APP/Contents/Resources/"
# No -v: macOS never counts a self-signed certificate as valid, so -v would hide it.
if security find-identity -p codesigning | grep -qF "\"$IDENTITY\""; then
  codesign --force --sign "$IDENTITY" "$APP"
  echo "Signed with the $IDENTITY certificate."
else
  codesign --force --sign - "$APP"
  echo "Signed ad-hoc: no $IDENTITY certificate in the keychain. macOS forgets Pauri's permissions after each ad-hoc rebuild."
fi
echo "$APP"
