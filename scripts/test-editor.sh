#!/bin/bash
# Focused range, Markdown, task, selection, and IME-defer checks for the native editor.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${DEVELOPER_DIR:-}" ]; then
    SELECTED_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
    if [ "$SELECTED_DEVELOPER_DIR" = "/Library/Developer/CommandLineTools" ] \
        && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    fi
fi

SDK="$(xcrun --show-sdk-path --sdk macosx)"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/nook-editor-tests.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT

APP_SOURCES=()
for SOURCE_FILE in "$ROOT"/Sources/*.swift; do
    [ "$(basename "$SOURCE_FILE")" = "Main.swift" ] || APP_SOURCES+=("$SOURCE_FILE")
done

# Tests only ever run on the machine that built them, so one native slice is
# enough — a universal test binary doubles the compile for a slice nobody runs.
swiftc -parse-as-library -swift-version 5 -D NOOK_TESTING \
    -target "$(uname -m)-apple-macosx15.0" \
    -sdk "$SDK" \
    "${APP_SOURCES[@]}" \
    "$ROOT"/Tests/*.swift \
    -o "$OUT/EditorStyleEngineTests"

"$OUT/EditorStyleEngineTests"
