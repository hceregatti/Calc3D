#!/usr/bin/env bash
# Compila em release para Apple Silicon e monta "build/Calc3D.app".
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Calc3D"
EXECUTABLE="Calc3D"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "▸ Compilando (release, arm64)…"
swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

echo "▸ Montando bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "▸ Gerando ícone…"
ICONSET="$(swift scripts/make-icon.swift "$BUILD_DIR")"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▸ Assinando (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "✔ Pronto: $APP"
