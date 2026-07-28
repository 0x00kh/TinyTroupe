#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
ARCH="${1:-universal}"

case "$ARCH" in
    x86_64|arm64|universal) ;;
    *)
        echo "Usage: $0 [x86_64|arm64|universal]" >&2
        exit 2
        ;;
esac

APP_DIR="$ROOT_DIR/dist/$ARCH/TinyTroupe.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
UNIVERSAL_BUILD_DIR="$ROOT_DIR/.build/universal"
X86_64_SCRATCH_DIR="$UNIVERSAL_BUILD_DIR/x86_64"
ARM64_SCRATCH_DIR="$UNIVERSAL_BUILD_DIR/arm64"
X86_64_TRIPLE="x86_64-apple-macosx13.0"
ARM64_TRIPLE="arm64-apple-macosx13.0"

cd "$ROOT_DIR"

build_arch() {
    local target_arch="$1"
    local triple scratch_dir

    if [[ "$target_arch" == "x86_64" ]]; then
        triple="$X86_64_TRIPLE"
        scratch_dir="$X86_64_SCRATCH_DIR"
    else
        triple="$ARM64_TRIPLE"
        scratch_dir="$ARM64_SCRATCH_DIR"
    fi

    swift build \
        -c release \
        --triple "$triple" \
        --scratch-path "$scratch_dir" \
        --product TinyTroupe >&2
    swift build \
        -c release \
        --triple "$triple" \
        --scratch-path "$scratch_dir" \
        --show-bin-path
}

if [[ "$ARCH" == "universal" ]]; then
    X86_64_BIN_DIR="$(build_arch x86_64)"
    ARM64_BIN_DIR="$(build_arch arm64)"
else
    BIN_DIR="$(build_arch "$ARCH")"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
if [[ "$ARCH" == "universal" ]]; then
    xcrun lipo -create \
        "$X86_64_BIN_DIR/TinyTroupe" \
        "$ARM64_BIN_DIR/TinyTroupe" \
        -output "$MACOS_DIR/TinyTroupe"
    xcrun lipo "$MACOS_DIR/TinyTroupe" -verify_arch x86_64 arm64
else
    cp "$BIN_DIR/TinyTroupe" "$MACOS_DIR/TinyTroupe"
    xcrun lipo "$MACOS_DIR/TinyTroupe" -verify_arch "$ARCH"
fi
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Assets/AppIcon/TinyTroupe.icns" "$RESOURCES_DIR/TinyTroupe.icns"
chmod +x "$MACOS_DIR/TinyTroupe"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
