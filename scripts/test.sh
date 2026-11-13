#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# Command Line Tools ship Swift Testing, but `swift test` does not search their Frameworks folder.
if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then
    F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
    exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" "$@"
fi
exec swift test "$@"
