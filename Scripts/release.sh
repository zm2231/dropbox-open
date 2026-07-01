#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: Scripts/release.sh <version> [--notes 'release notes']" >&2
  echo "example: Scripts/release.sh 1.1" >&2
  exit 1
fi
shift || true

NOTES="Release v${VERSION}."
if [ "${1:-}" = "--notes" ]; then
  NOTES="$2"
fi

REPO="zm2231/dropbox-open"
TAP_REPO="zm2231/homebrew-tap"
TAP_LOCAL="/Volumes/4/GitHub/homebrew-tap"
TAP_CELLAR="/opt/homebrew/Library/Taps/zm2231/homebrew-tap"
APP_PLIST="$ROOT/Sources/DropboxOpen/Resources/Info.plist"
EXT_PLIST="$ROOT/Sources/DropboxOpenFinderSync/Resources/Info.plist"
CASK="$ROOT/Casks/dropbox-open.rb"
TAG="v${VERSION}"
DOT_ZIP_NAME="Dropbox.Deeplink.zip"

echo "==> bumping version to ${VERSION}"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PLIST")"
NEXT_BUILD=$((CURRENT_BUILD + 1))
for plist in "$APP_PLIST" "$EXT_PLIST"; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEXT_BUILD}" "$plist"
done
ruby -e "
  content = File.read('$CASK')
  content.sub!(/version \".*?\"/, 'version \"${VERSION}\"')
  File.write('$CASK', content)
"

echo "==> swift test"
swift test

echo "==> Scripts/build-app.sh"
NOTARIZE="${NOTARIZE:-1}" ./Scripts/build-app.sh

echo "==> preparing release asset with a GitHub-safe filename (GitHub renames spaces to dots on upload)"
cp "$ROOT/dist/Dropbox Deeplink.zip" "$ROOT/dist/${DOT_ZIP_NAME}"
SHA=$(shasum -a 256 "$ROOT/dist/${DOT_ZIP_NAME}" | awk '{print $1}')
echo "sha256: $SHA"

echo "==> updating Cask (version + sha256 + url)"
ruby -e "
  content = File.read('$CASK')
  content.sub!(/sha256 .*/, 'sha256 \"${SHA}\"')
  content.sub!(%r{url \".*?\"}, 'url \"https://github.com/${REPO}/releases/download/v#{version}/${DOT_ZIP_NAME}\"')
  File.write('$CASK', content)
"

echo "==> committing and pushing ${REPO}"
git add -A
git commit -m "Release ${TAG}"
git push

echo "==> cutting/updating GitHub release ${TAG}"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ROOT/dist/${DOT_ZIP_NAME}" --clobber --repo "$REPO"
else
  gh release create "$TAG" "$ROOT/dist/${DOT_ZIP_NAME}" --title "$TAG" --notes "$NOTES" --repo "$REPO"
fi

echo "==> syncing Cask to tap repo copies"
cp "$CASK" "$TAP_LOCAL/Casks/dropbox-open.rb"
(cd "$TAP_LOCAL" && git add -A && git commit -m "Release ${TAG}" && git push)
if [ -d "$TAP_CELLAR" ]; then
  cp "$CASK" "$TAP_CELLAR/Casks/dropbox-open.rb"
fi

echo "==> verifying end-to-end brew install"
brew untap zm2231/tap >/dev/null 2>&1 || true
brew tap zm2231/tap
brew reinstall --cask zm2231/tap/dropbox-open

echo "==> done. ${TAG} released and verified via brew."
