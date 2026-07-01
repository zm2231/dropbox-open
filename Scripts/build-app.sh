#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DropboxOpen"
APP_DISPLAY_NAME="Dropbox Deeplink"
FINDER_SYNC_NAME="DropboxOpenFinderSync"
BUNDLE_ID="com.quoxient.dropbox-open"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: ZAIN SOHAIL MERCHANT (Q5Y75DVV4M)}"
BUILD_DIR="$ROOT/.build/release"
DIST_DIR="$ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
FINDER_SYNC_BUNDLE="$APP_BUNDLE/Contents/PlugIns/$FINDER_SYNC_NAME.appex"
MACOS_SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"

NOTARIZE="${NOTARIZE:-1}"
NOTARY_PROFILE="${NOTARY_PROFILE:-dropbox-open-notary}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  CODESIGN_TIMESTAMP=(--timestamp=none)
else
  CODESIGN_TIMESTAMP=(--timestamp)
fi

assert_distribution_signature() {
  local bundle="$1"
  local details
  details="$(codesign -dvvv "$bundle" 2>&1)"
  if ! grep -q "Authority=$SIGN_IDENTITY" <<<"$details"; then
    echo "error: $bundle is not signed with the expected certificate: $SIGN_IDENTITY" >&2
    echo "$details" >&2
    exit 1
  fi
  if ! grep -q "TeamIdentifier=Q5Y75DVV4M" <<<"$details"; then
    echo "error: $bundle is missing the expected Developer ID team identifier" >&2
    echo "$details" >&2
    exit 1
  fi
}

echo "==> swift build -c release"
cd "$ROOT"
swift build -c release

echo "==> assembling $APP_DISPLAY_NAME.app"
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$FINDER_SYNC_BUNDLE/Contents/MacOS"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Sources/DropboxOpen/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT/Sources/DropboxOpenFinderSync/Resources/Info.plist" "$FINDER_SYNC_BUNDLE/Contents/Info.plist"

echo "==> compiling Finder Sync extension"
xcrun swiftc \
  -O \
  -application-extension \
  -module-name "$FINDER_SYNC_NAME" \
  -target "$ARCH-apple-macos13.0" \
  -sdk "$MACOS_SDK" \
  -framework Cocoa \
  -framework FinderSync \
  "$ROOT/Sources/DropboxOpenCore/BoxIcon.swift" \
  "$ROOT/Sources/DropboxOpenCore/WorkspaceStore.swift" \
  "$ROOT/Sources/DropboxOpenFinderSync/FinderSync.swift" \
  "$ROOT/Sources/DropboxOpenFinderSync/main.swift" \
  -o "$FINDER_SYNC_BUNDLE/Contents/MacOS/$FINDER_SYNC_NAME"

echo "==> codesign Finder Sync extension ($SIGN_IDENTITY)"
codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" \
  --entitlements "$ROOT/Entitlements/DropboxOpenFinderSync.entitlements" \
  --sign "$SIGN_IDENTITY" \
  "$FINDER_SYNC_BUNDLE"

echo "==> codesign app ($SIGN_IDENTITY)"
codesign --force --options runtime "${CODESIGN_TIMESTAMP[@]}" \
  --entitlements "$ROOT/Entitlements/DropboxOpen.entitlements" \
  --sign "$SIGN_IDENTITY" \
  "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
if [ "$SIGN_IDENTITY" != "-" ]; then
  assert_distribution_signature "$FINDER_SYNC_BUNDLE"
  assert_distribution_signature "$APP_BUNDLE"
fi

if [ "$NOTARIZE" = "1" ]; then
  echo "==> notarizing (profile: $NOTARY_PROFILE)"
  ZIP_PATH="$DIST_DIR/$APP_NAME-for-notarize.zip"
  ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$ZIP_PATH"
else
  echo "==> skipping notarization (NOTARIZE=0)"
fi

RELEASE_ZIP="$DIST_DIR/$APP_DISPLAY_NAME.zip"
echo "==> zipping release artifact: $RELEASE_ZIP"
(cd "$DIST_DIR" && zip -r -q "$APP_DISPLAY_NAME.zip" "$APP_DISPLAY_NAME.app")

echo "==> sha256:"
shasum -a 256 "$RELEASE_ZIP"

echo "==> done. App bundle: $APP_BUNDLE"
