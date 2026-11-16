#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

stop() {
  echo "bump-cask: $1" >&2
  exit 1
}

VERSION="${1:-}"
DRY_RUN="${2:-}"
if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || [ $# -gt 2 ] ||
  { [ -n "$DRY_RUN" ] && [ "$DRY_RUN" != --dry-run ]; }; then
  stop "usage: scripts/bump-cask.sh X.Y.Z [--dry-run]"
fi

SHA="$(gh release view "v$VERSION" --repo godfreyponce/pauri --json assets \
  -q '.assets[] | select(.name == "Pauri.zip") | .digest' 2>/dev/null)" || SHA=""
SHA="${SHA#sha256:}"
echo "$SHA" | grep -Eq '^[0-9a-f]{64}$' ||
  stop "No sha256 for Pauri.zip on release v$VERSION. Is the release out?"

TAP=build/tap
rm -rf "$TAP"
if [ -n "$DRY_RUN" ]; then
  git init -q "$TAP"
else
  gh repo clone godfreyponce/homebrew-tap "$TAP" -- -q ||
    stop "Cannot clone godfreyponce/homebrew-tap. Make it first: gh repo create godfreyponce/homebrew-tap --public"
fi

mkdir -p "$TAP/Casks"
cat > "$TAP/Casks/pauri.rb" <<EOF
cask "pauri" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/godfreyponce/pauri/releases/download/v#{version}/Pauri.zip"
  name "Pauri"
  desc "Floating quick-chat panel for the Codex CLI"
  homepage "https://github.com/godfreyponce/pauri"

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Pauri.app"
end
EOF
cat > "$TAP/README.md" <<EOF
# godfreyponce/homebrew-tap

Homebrew casks for [Pauri](https://github.com/godfreyponce/pauri).

    brew install --cask godfreyponce/tap/pauri

Pauri is not signed by Apple, so macOS asks you to allow it the first time you open it. See Pauri's [Install](https://github.com/godfreyponce/pauri#install) steps 4 to 6. Pauri updates itself, so \`brew upgrade\` leaves it alone.

Pauri's \`scripts/bump-cask.sh\` writes the files in this repo at each release. Edits made here are overwritten.
EOF

if [ -n "$DRY_RUN" ]; then
  echo "Dry run: nothing pushed."
  echo "$TAP/Casks/pauri.rb"
  exit 0
fi

git -C "$TAP" add -A
if git -C "$TAP" diff --cached --quiet; then
  echo "The cask already has $VERSION."
  exit 0
fi
git -C "$TAP" commit -q -m "pauri $VERSION"
git -C "$TAP" push -q origin HEAD:main
echo "Bumped the cask to $VERSION: https://github.com/godfreyponce/homebrew-tap/blob/main/Casks/pauri.rb"
