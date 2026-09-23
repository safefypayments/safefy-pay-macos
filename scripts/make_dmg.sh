#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
APP="dist/Safefy Pay.app"
ICON="Resources/AppIcon.icns"
STAGE="dist/dmg-stage"
RW_DMG="dist/rw.dmg"
DMG="dist/Safefy Pay.dmg"

rm -rf "$STAGE" "$RW_DMG" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ICON" "$STAGE/.VolumeIcon.icns"

hdiutil create -volname "Safefy Pay" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW_DMG" >/dev/null
attach_output=$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)
mount_dir=$(echo "$attach_output" | grep -o '/Volumes/.*')
SetFile -a C "$mount_dir"
hdiutil detach "$mount_dir" >/dev/null

hdiutil convert "$RW_DMG" -format UDZO -o "$DMG" >/dev/null
rm -rf "$STAGE" "$RW_DMG"

# Give the .dmg file itself the same custom icon (shown in Finder before mounting).
dmgicon=$(mktemp /tmp/dmgicon-XXXX.icns)
cp "$ICON" "$dmgicon"
sips -i "$dmgicon" >/dev/null
rsrc=$(mktemp /tmp/dmgicon-XXXX.rsrc)
DeRez -only icns "$dmgicon" > "$rsrc"
Rez -append "$rsrc" -o "$DMG"
SetFile -a C "$DMG"
rm -f "$dmgicon" "$rsrc"

echo "DMG criado: $DMG"
