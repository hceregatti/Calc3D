#!/usr/bin/env bash
# Gera "build/Calc3D-<versão>.dmg" com o app e um atalho para /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Calc3D"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

[ -d "$APP" ] || ./scripts/build-app.sh

echo "▸ Montando imagem de disco…"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

echo "✔ Pronto: $DMG"
