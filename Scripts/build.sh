#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="Keyli"
VERSION=$(awk -F'"' '/"version"/ { print $4; exit }' "$ROOT_DIR/package.json")
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

cd "$ROOT_DIR"

echo "▶ Building $APP_NAME (release)..."
swift build -c release --build-system native 2>&1 | sed '/warning:.*build-system native.*deprecated/d'

echo "▶ Packaging $APP_NAME.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Support/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT_DIR"/Support/Icons/*.png "$ROOT_DIR"/Support/Icons/*.icns "$RESOURCES_DIR"/ 2>/dev/null || true
cp "$ROOT_DIR"/Support/Sounds/*.aiff "$RESOURCES_DIR"/ 2>/dev/null || true
if [[ -d "$ROOT_DIR/Support/SoundPacks" ]]; then
    ditto "$ROOT_DIR/Support/SoundPacks" "$RESOURCES_DIR/SoundPacks"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true
if [[ -n "${KEYLI_CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --sign "$KEYLI_CODESIGN_IDENTITY" "$APP_DIR"
else
    codesign \
        --force \
        --deep \
        --sign - \
        --requirements '=designated => identifier "io.coreify.keyli" and info[CFBundleIdentifier] = "io.coreify.keyli"' \
        "$APP_DIR"
fi
REQUIREMENT=$(codesign --display --requirements - "$APP_DIR" 2>&1 || true)
if ! grep -q 'designated => .*identifier "io.coreify.keyli"' <<<"$REQUIREMENT" || grep -q 'cdhash' <<<"$REQUIREMENT"; then
    echo "❌ Unstable designated requirement. macOS privacy grants would reset on every build:" >&2
    echo "$REQUIREMENT" >&2
    exit 1
fi
codesign --verify --strict --deep "$APP_DIR"
echo "✅ $APP_NAME.app ready: $APP_DIR"

if [[ "${1:-}" == "--run" ]]; then
    echo "▶ Launching $APP_NAME..."
    open "$APP_DIR"
fi
