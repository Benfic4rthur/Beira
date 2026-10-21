#!/bin/bash
set -euo pipefail
BEIRA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BEIRA_DEST="/Applications/Beira.app"
"$BEIRA_ROOT/scripts/build.sh"
if pgrep -f '^(/Applications/Beira.app|.*/beira/build/Beira.app)/Contents/MacOS/Beira$' >/dev/null; then
    printf 'Encerre o Beira pelo menu antes de atualizar o aplicativo.\n' >&2
    exit 1
fi
if [[ -e "$BEIRA_DEST" ]]; then
    BEIRA_EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BEIRA_DEST/Contents/Info.plist")
    if [[ "$BEIRA_EXISTING_ID" != "com.arthurbenfica.beira" ]]; then
        printf 'O aplicativo no destino tem outra identidade; instalação interrompida.\n' >&2
        exit 1
    fi
fi
ditto "$BEIRA_ROOT/build/Beira.app" "$BEIRA_DEST"
codesign --verify --strict "$BEIRA_DEST"
open "$BEIRA_DEST"
printf 'Beira instalado em %s\n' "$BEIRA_DEST"
