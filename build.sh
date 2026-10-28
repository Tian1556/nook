#!/bin/bash
# Builds Nook.app with the Swift command-line toolchain.
#   ./build.sh          release build
#   ./build.sh debug    fast build, no optimisation
#   ./build.sh run      build then relaunch the app
#
# Set MARKETING_VERSION / BUILD_NUMBER to stamp the bundle (CI does this from the tag).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# A newly installed Xcode does not automatically replace Command Line Tools as
# the active developer directory. Prefer the full toolchain when it is present,
# while still respecting an explicit DEVELOPER_DIR or another selected Xcode.
if [ -z "${DEVELOPER_DIR:-}" ]; then
    SELECTED_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
    if [ "$SELECTED_DEVELOPER_DIR" = "/Library/Developer/CommandLineTools" ] \
        && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    fi
fi

APP="$ROOT/build/Nook.app"
BIN_DIR="$ROOT/build/.nook-bin"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
MODE="${1:-release}"

MARKETING_VERSION="${MARKETING_VERSION:-1.9.2}"
BUILD_NUMBER="${BUILD_NUMBER:-202}"

OPT="-O"
[ "$MODE" = "debug" ] && OPT="-Onone"

rm -rf "$APP"
rm -rf "$BIN_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$BIN_DIR"
trap 'rm -rf "$BIN_DIR"' EXIT

echo "→ compiling ($MODE) $MARKETING_VERSION ($BUILD_NUMBER)"
# Releases ship one DMG per architecture — a universal binary cost a third of
# the download for a slice each Mac ignores. BUILD_ARCHS picks the slice(s);
# the default keeps local release builds universal, which is convenient for
# testing both, and debug builds stay native-only for speed.
ARCHES=(${BUILD_ARCHS:-arm64 x86_64})
[ "$MODE" = "debug" ] && ARCHES=("$(uname -m)")
for ARCH in "${ARCHES[@]}"; do
    echo "→ compiling $ARCH"
    swiftc $OPT -parse-as-library -swift-version 5 \
        -target "${ARCH}-apple-macosx15.0" \
        -sdk "$SDK" \
        "$ROOT"/Sources/*.swift \
        -o "$BIN_DIR/Nook-$ARCH"
done
if [ "${#ARCHES[@]}" -gt 1 ]; then
    lipo -create "$BIN_DIR/Nook-arm64" "$BIN_DIR/Nook-x86_64" \
        -output "$APP/Contents/MacOS/Nook"
    lipo -info "$APP/Contents/MacOS/Nook" | grep -Eq 'arm64.*x86_64|x86_64.*arm64'
else
    cp "$BIN_DIR/Nook-${ARCHES[0]}" "$APP/Contents/MacOS/Nook"
fi

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
for LOCALIZATION in "$ROOT"/Resources/*.lproj; do
    [ -d "$LOCALIZATION" ] && cp -R "$LOCALIZATION" "$APP/Contents/Resources/"
done
[ -f "$ROOT/LICENSE" ] && cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE.txt"
[ -f "$ROOT/licenses/THIRD-PARTY.txt" ] && cp "$ROOT/licenses/THIRD-PARTY.txt" "$APP/Contents/Resources/"

printf 'APPL????' > "$APP/Contents/PkgInfo"

IDENTITY="${CODESIGN_IDENTITY:--}"
SIGN_OPTS=(--force --sign "$IDENTITY")
[ "$IDENTITY" != "-" ] && SIGN_OPTS+=(--options runtime --timestamp)
codesign "${SIGN_OPTS[@]}" "$APP"
codesign --verify --deep --strict "$APP" && echo "✓ signature valid"

echo "✓ built $APP"

if [ "$MODE" = "run" ] || [ "${2:-}" = "run" ]; then
    pkill -x Nook 2>/dev/null || true
    sleep 0.4
    open "$APP"
    echo "✓ launched"
fi
