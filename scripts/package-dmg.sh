#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_NAME="TinyTroupe"
INFO_PLIST="$ROOT_DIR/Packaging/Info.plist"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
ARCH="${1:-all}"

case "$ARCH" in
    x86_64|arm64|universal) ARCHES=("$ARCH") ;;
    all) ARCHES=(x86_64 arm64) ;;
    *)
        echo "Usage: $0 [x86_64|arm64|universal|all]" >&2
        exit 2
        ;;
esac

for target_arch in "${ARCHES[@]}"; do
    APP_DIR="$ROOT_DIR/dist/$target_arch/$APP_NAME.app"
    DMG_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION-$target_arch.dmg"
    STAGING_DIR="$ROOT_DIR/.build/dmg-root-$target_arch"

    "$ROOT_DIR/scripts/build-app.sh" "$target_arch" >/dev/null

    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR"
    ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
    ln -s /Applications "$STAGING_DIR/Applications"

    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -fs HFS+ \
        -format UDZO \
        -imagekey zlib-level=9 \
        -ov \
        "$DMG_PATH" >/dev/null

    codesign --force --sign - "$DMG_PATH"
    rm -rf "$STAGING_DIR"
    echo "$DMG_PATH"
done
