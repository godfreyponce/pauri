#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# Command Line Tools ship Swift Testing, but `swift test` does not search their Frameworks folder.
# Their _Testing_Foundation overlay has no Modules folder, so a test file that imports both
# Foundation and Testing fails with "no such module" unless cross-import overlays are off.
if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then
    F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
    exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays "$@"
fi
exec swift test "$@"
