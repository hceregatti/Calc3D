#!/usr/bin/env bash
# Compila em release (universal: Apple Silicon + Intel) e monta "build/Calc3D.app".
# Para compilar só uma arquitetura: ARCHS="arm64" ./scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Calc3D"
EXECUTABLE="Calc3D"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

ARCHS="${ARCHS:-arm64 x86_64}"
ARCH_FLAGS=()
for a in $ARCHS; do ARCH_FLAGS+=(--arch "$a"); done

echo "▸ Compilando (release, $ARCHS)…"
swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

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
