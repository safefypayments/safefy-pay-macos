#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="dist/Safefy Pay.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/SafefyPay "$APP/Contents/MacOS/SafefyPay"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi
if [ -f Resources/MenuBarIcon.png ]; then cp Resources/MenuBarIcon.png "$APP/Contents/Resources/MenuBarIcon.png"; fi
if [ -d Resources/Icons ]; then rm -rf "$APP/Contents/Resources/Icons"; cp -R Resources/Icons "$APP/Contents/Resources/Icons"; fi
if [ -d Resources/Splash ]; then rm -rf "$APP/Contents/Resources/Splash"; cp -R Resources/Splash "$APP/Contents/Resources/Splash"; fi

rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -R .build/release/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"
if ! otool -l "$APP/Contents/MacOS/SafefyPay" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/SafefyPay"
fi

codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate.app" 2>/dev/null || true
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP"
echo "Aplicativo criado: $APP"
