#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product Pauri
BIN="$(swift build -c release --show-bin-path)/Pauri"
APP=build/Pauri.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Pauri"
cp Support/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Support/OAI_OpenAI-Blossom_Black.svg Support/OAI_OpenAI-Blossom_White.svg "$APP/Contents/Resources/"
echo "$APP"
