#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DropboxOpen"
APP_DISPLAY_NAME="Dropbox Deeplink"
BUNDLE_ID="com.quoxient.dropbox-open"
SIGN_IDENTITY="Developer ID Application: ZAIN SOHAIL MERCHANT (Q5Y75DVV4M)"
BUILD_DIR="$ROOT/.build/release"
DIST_DIR="$ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
QUICK_ACTION_NAME="Copy Dropbox Deeplink.workflow"
QUICK_ACTION_SRC="$ROOT/QuickAction/$QUICK_ACTION_NAME"

NOTARIZE="${NOTARIZE:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-dropbox-open-notary}"

echo "==> swift build -c release"
cd "$ROOT"
swift build -c release

echo "==> assembling $APP_DISPLAY_NAME.app"
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Sources/DropboxOpen/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> codesign ($SIGN_IDENTITY)"
codesign --force --deep --options runtime --timestamp \
  --sign "$SIGN_IDENTITY" \
  "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> staging Quick Action"
cp -R "$QUICK_ACTION_SRC" "$DIST_DIR/$QUICK_ACTION_NAME"

if [ "$NOTARIZE" = "1" ]; then
  echo "==> notarizing (profile: $NOTARY_PROFILE)"
  ZIP_PATH="$DIST_DIR/$APP_NAME-for-notarize.zip"
  ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  rm -f "$ZIP_PATH"
else
  echo "==> skipping notarization (set NOTARIZE=1 to enable)"
fi

RELEASE_ZIP="$DIST_DIR/$APP_DISPLAY_NAME.zip"
echo "==> zipping release artifact: $RELEASE_ZIP"
(cd "$DIST_DIR" && zip -r -q "$APP_DISPLAY_NAME.zip" "$APP_DISPLAY_NAME.app" "$QUICK_ACTION_NAME")

echo "==> sha256:"
shasum -a 256 "$RELEASE_ZIP"

echo "==> done. App bundle: $APP_BUNDLE"
