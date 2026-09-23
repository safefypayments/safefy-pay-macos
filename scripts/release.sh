#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?Uso: scripts/release.sh <versao> (ex: 0.2.0)}"

SPARKLE_BIN="${SPARKLE_BIN:-.sparkle-tools/bin}"
if [ ! -x "$SPARKLE_BIN/generate_appcast" ]; then
  echo "Ferramentas do Sparkle não encontradas em $SPARKLE_BIN."
  echo "Baixe a distribuição completa (mesma versão usada no Package.swift) em:"
  echo "  https://github.com/sparkle-project/Sparkle/releases"
  echo "e extraia a pasta bin/ para $SPARKLE_BIN/"
  exit 1
fi

plutil -replace CFBundleShortVersionString -string "$VERSION" Resources/Info.plist
CURRENT_BUILD=$(plutil -extract CFBundleVersion raw Resources/Info.plist)
plutil -replace CFBundleVersion -string "$((CURRENT_BUILD + 1))" Resources/Info.plist

./scripts/make_dmg.sh

mkdir -p releases
cp "dist/Safefy Pay.dmg" "releases/Safefy Pay $VERSION.dmg"

"$SPARKLE_BIN/generate_appcast" releases \
  --download-url-prefix "https://github.com/safefypayments/safefy-pay-macos/releases/download/v$VERSION/"

cp "releases/appcast.xml" appcast.xml

cat <<EOF

DMG e appcast.xml gerados para v$VERSION. Passos manuais restantes:

1. git add Resources/Info.plist appcast.xml
   git commit -m "Release v$VERSION"
   git push

2. gh release create v$VERSION "releases/Safefy Pay $VERSION.dmg" \\
     --title "v$VERSION" --notes "Notas da versão aqui"

O appcast.xml só deve ser commitado/enviado DEPOIS que o release existir no
GitHub, já que ele aponta para a URL de download daquele release.
EOF
