#!/bin/bash
# Verifies that the personal fork is isolated from the upstream app identity.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Info.plist"
APP="$ROOT/build/Nook.app"

fail() {
    echo "✗ $1" >&2
    exit 1
}

[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PLIST")" = "Nook" ] \
    || fail "CFBundleName is not Nook"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" = "local.nook.Nook" ] \
    || fail "Bundle ID is not isolated"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")" = "Nook" ] \
    || fail "executable name is not Nook"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$PLIST")" = "nook" ] \
    || fail "URL scheme is not nook"

if /usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$PLIST" >/dev/null 2>&1; then
    fail "upstream update feed is still configured"
fi
if /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$PLIST" >/dev/null 2>&1; then
    fail "upstream update key is still configured"
fi

rg -q 'appendingPathComponent\("Nook"' "$ROOT/Sources/Core.swift" \
    || fail "Application Support directory is not Nook"
rg -q 'url\.scheme == "nook"' "$ROOT/Sources/AppDelegate.swift" \
    || fail "runtime URL routing is not nook://"
if rg -q 'Updater|canImport\(Sparkle\)|SUFeedURL|SUPublicEDKey' \
    "$ROOT/Sources" "$ROOT/Info.plist" "$ROOT/build.sh"; then
    fail "automatic update code is still active"
fi

if [ -d "$APP" ]; then
    BUILT_PLIST="$APP/Contents/Info.plist"
    [ -x "$APP/Contents/MacOS/Nook" ] || fail "built Nook executable is missing"
    [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILT_PLIST")" = "local.nook.Nook" ] \
        || fail "built app has the wrong Bundle ID"
    if [ -d "$APP/Contents/Frameworks/Sparkle.framework" ]; then
        fail "built app still bundles Sparkle"
    fi
fi

echo "✓ Nook identity and update isolation verified"
