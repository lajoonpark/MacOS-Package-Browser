#!/usr/bin/env bash
# Builds the app and packages it into dist/Package-Browser-<version>.dmg
# with a standard drag-to-Applications layout.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Package Browser"

echo "==> Building app bundle"
./scripts/build-app.sh

APP="dist/${APP_NAME}.app"
VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
DMG="dist/Package-Browser-${VERSION}.dmg"

echo "==> Staging $APP"
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating $DMG"
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"

echo "==> Done: $DMG"
