#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PACKAGE_JSON="$APP_DIR/package.json"
PLIST_FILE="$APP_DIR/Support/Info.plist"
CHANGELOG_FILE="$APP_DIR/CHANGELOG.md"

if [ ! -f "$PACKAGE_JSON" ] || [ ! -f "$PLIST_FILE" ]; then
    echo "Error: Required files not found in $APP_DIR" >&2
    exit 1
fi

CURRENT_VERSION=$(awk -F'"' '/"version"/ { print $4; exit }' "$PACKAGE_JSON")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_FILE" 2>/dev/null || echo "1")

IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION%%-*}"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

SUGGESTED_PATCH="$MAJOR.$MINOR.$((PATCH + 1))"
SUGGESTED_MINOR="$MAJOR.$((MINOR + 1)).0"
SUGGESTED_MAJOR="$((MAJOR + 1)).0.0"
SUGGESTED_BUILD=$((CURRENT_BUILD + 1))

INPUT_VERSION="${1:-}"
INPUT_BUILD="${2:-}"

if [ -z "$INPUT_VERSION" ]; then
    echo "Current version: $CURRENT_VERSION (build $CURRENT_BUILD)"
    echo ""
    echo "Select bump type:"
    echo "  1) Patch  -> $SUGGESTED_PATCH"
    echo "  2) Minor  -> $SUGGESTED_MINOR"
    echo "  3) Major  -> $SUGGESTED_MAJOR"
    echo "  4) Custom"
    read -r -p "Enter choice [1-4] (default: 1): " CHOICE

    case "$CHOICE" in
        2) TARGET_VERSION="$SUGGESTED_MINOR" ;;
        3) TARGET_VERSION="$SUGGESTED_MAJOR" ;;
        4) read -r -p "Enter new version: " TARGET_VERSION ;;
        *) TARGET_VERSION="$SUGGESTED_PATCH" ;;
    esac
else
    TARGET_VERSION="$INPUT_VERSION"
fi

if [ -z "$INPUT_BUILD" ]; then
    TARGET_BUILD="$SUGGESTED_BUILD"
else
    TARGET_BUILD="$INPUT_BUILD"
fi

sed -i '' -E 's/("version": ")[^"]+(")/\1'"$TARGET_VERSION"'\2/' "$PACKAGE_JSON"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $TARGET_VERSION" "$PLIST_FILE"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $TARGET_BUILD" "$PLIST_FILE"

echo "✅ Version bumped to $TARGET_VERSION (build $TARGET_BUILD) successfully!"
