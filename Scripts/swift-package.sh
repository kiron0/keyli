#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/ModuleCache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$CLANG_MODULE_CACHE_PATH}"
PACKAGE_OPTIONS=(
    --cache-path "$ROOT_DIR/.build/cache"
    --config-path "$ROOT_DIR/.build/configuration"
    --security-path "$ROOT_DIR/.build/security"
)

DEVELOPER_PATH="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ "$DEVELOPER_PATH" == *".app/Contents/Developer"* ]]; then
    swift "$@" "${PACKAGE_OPTIONS[@]}"
else
    if [[ "${1:-}" == "test" ]]; then
        TESTING_FRAMEWORKS="$DEVELOPER_PATH/Library/Developer/Frameworks"
        if [[ -d "$TESTING_FRAMEWORKS/Testing.framework" ]]; then
            PACKAGE_OPTIONS+=(-Xswiftc -F -Xswiftc "$TESTING_FRAMEWORKS")
        fi
    fi
    swift "$@" "${PACKAGE_OPTIONS[@]}" --build-system native 2>&1 |
        LC_ALL=C sed -E '/warning:.*build-system native.*deprecated/d'
fi
