#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
DOCS="$(cd "$ROOT/../../docs" && pwd)/assets/shots"
README_SHOTS="$ROOT/Support/Screenshots"
ICON="$ROOT/Support/Icons/AppIcon.iconset/icon_512x512@2x.png"
APP="${KEYLI_APP:-/Applications/Keyli.app}"
W="${SHOTS_WORK:-$(mktemp -d)}"
BACKUP="$W/keyli-prefs.plist"

mkdir -p "$W/bin"
for tool in backdrop poster move winid overlay; do
    swiftc -O "$HERE/$tool.swift" -o "$W/bin/$tool"
done

TARGET="$W/TextEdit.app/Contents"
mkdir -p "$TARGET/MacOS" "$TARGET/Resources"
cp "$W/bin/backdrop" "$TARGET/MacOS/backdrop"
cp /System/Applications/TextEdit.app/Contents/Resources/AppIcon.icns "$TARGET/Resources/"
cat > "$TARGET/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>backdrop</string>
<key>CFBundleIdentifier</key><string>local.keyli.screenshots.backdrop</string>
<key>CFBundleName</key><string>TextEdit</string>
<key>CFBundleDisplayName</key><string>TextEdit</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - "$W/TextEdit.app" >/dev/null 2>&1
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$W/TextEdit.app"

for variant in hero themes studio keyboard settings sounds shortcuts; do
    "$W/bin/poster" "$variant" "$W/bg_$variant.png" "$HERE/fonts" "$ICON" >/dev/null
done

defaults export io.coreify.keyli "$BACKUP"

ax() { osascript -e "tell application \"System Events\" to tell process \"Keyli\" to $1"; }
quit_keyli() {
    osascript -e 'tell application id "io.coreify.keyli" to quit' >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do pgrep -x Keyli >/dev/null || return 0; sleep 0.25; done
    pkill -x Keyli || true
    sleep 0.5
}
backdrop() {
    pkill -f "TextEdit.app/Contents/MacOS/backdrop" 2>/dev/null || true
    sleep 0.3
    "$TARGET/MacOS/backdrop" "$W/bg_$1.png" >/dev/null 2>&1 &
    sleep 1.2
}
launch() {
    quit_keyli
    python3 "$HERE/setcfg.py" "$W" "$@"
    open -a "$APP"
    sleep 2.5
}
raise() {
    osascript -e 'tell application id "io.coreify.keyli" to activate' >/dev/null
    ax "perform action \"AXRaise\" of window \"$1\"" >/dev/null
    sleep 0.8
}
grab() {
    screencapture -x "$W/raw_$1.png"
    sips -c 1800 3360 --cropOffset 68 0 "$W/raw_$1.png" --out "$W/cap_$1.png" >/dev/null
}
shot() {
    "$W/bin/move" 20 1040
    sleep 0.4
    grab "$1"
}
window_capture() {
    "$W/bin/move" 20 1040
    sleep 0.4
    screencapture -x -l"$("$W/bin/winid" Keyli)" "$W/win_$1.png"
    ax 'get (position of window 1) & (size of window 1)' | tr -d ' ' | tr ',' ' ' > "$W/frame_$1.txt"
}
status_menu() {
    osascript -e 'tell application "System Events" to tell process "Keyli" to ignoring application responses' \
        -e 'click menu bar item 1 of menu bar 2' -e 'end ignoring'
    sleep 1
    ax "click menu item \"$1\" of menu 1 of menu bar item 1 of menu bar 2" >/dev/null
    sleep 1.5
}
settings_page() {
    backdrop "$1"
    ax "click button $2 of group 1 of window \"Keyli Settings\"" >/dev/null
    raise "Keyli Settings"
    sleep 0.7
    shot "$1"
}
restore() {
    pkill -f "TextEdit.app/Contents/MacOS/backdrop" 2>/dev/null || true
    quit_keyli
    defaults import io.coreify.keyli "$BACKUP"
    open -a "$APP"
}
trap restore EXIT

backdrop hero
launch ember_graphite 790 180 840 420 1
shot hero

backdrop keyboard
launch oxblood 105 473 858 426 1
"$W/bin/move" 20 1040
osascript -e 'tell application "System Events" to tell process "Keyli" to ignoring application responses' \
    -e 'perform action "AXPress" of menu button "Keyboard Options" of group 1 of window 1' -e 'end ignoring'
sleep 1
read -r mx my < <(ax 'get position of menu item "Opacity" of menu 1 of menu button "Keyboard Options" of group 1 of window 1' | tr -d ' ' | tr ',' ' ')
"$W/bin/move" $((mx + 60)) $((my + 12))
sleep 0.3
"$W/bin/move" $((mx + 70)) $((my + 12))
sleep 1
grab keyboard
osascript -e 'tell application "System Events" to key code 53'

backdrop themes
launch kiln 101 525 756 420 1
shot kiln
launch riso_print 882 475 756 410 1
window_capture riso
launch blacklight 902 132 753 400 1
window_capture blacklight
"$W/bin/overlay" "$W/cap_kiln.png" "$W/cap_themes.png" \
    "$W/win_riso.png" $(cat "$W/frame_riso.txt") \
    "$W/win_blacklight.png" $(cat "$W/frame_blacklight.txt") >/dev/null

backdrop sounds
launch ember_graphite 790 180 840 420 0
status_menu "Settings…"
ax 'set position of window "Keyli Settings" to {761, 79}' >/dev/null
settings_page sounds 3
settings_page shortcuts 4
settings_page settings 6

ax 'click button 1 of window "Keyli Settings"' >/dev/null
status_menu "Theme Studio…"
ax 'set position of window "Keyli Theme Studio" to {563, 61}' >/dev/null
backdrop studio
raise "Keyli Theme Studio"
shot studio

restore
trap - EXIT

for pair in hero:hero keyboard:keyboard themes:themes studio:theme-studio settings:settings sounds:sounds shortcuts:shortcuts; do
    src="$W/cap_${pair%%:*}.png"
    name="${pair##*:}"
    cwebp -quiet -q 90 -m 6 -sharp_yuv -metadata none "$src" -o "$DOCS/$name.webp"
    cwebp -quiet -q 88 -m 6 -sharp_yuv -metadata none -resize 2240 0 "$src" -o "$DOCS/$name-2240.webp"
    cwebp -quiet -q 86 -m 6 -sharp_yuv -metadata none -resize 1280 0 "$src" -o "$DOCS/$name-1280.webp"
    sips -s format jpeg -s formatOptions 86 "$src" --out "$DOCS/$name.jpg" >/dev/null
    sips -s format jpeg -s formatOptions 86 -Z 2560 "$src" --out "$README_SHOTS/$name.jpg" >/dev/null
done

echo "Screenshots written to $DOCS and $README_SHOTS (work files: $W)"
