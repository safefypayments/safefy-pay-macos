#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="dist/Safefy Pay.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SafefyPay "$APP/Contents/MacOS/SafefyPay"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi
if [ -f Resources/MenuBarIcon.png ]; then cp Resources/MenuBarIcon.png "$APP/Contents/Resources/MenuBarIcon.png"; fi
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "Aplicativo criado: $APP"
