#!/bin/bash
set -euo pipefail
BEIRA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BEIRA_ROOT"
BEIRA_ARCH="${BEIRA_ARCH:-$(uname -m)}"
case "$BEIRA_ARCH" in
    arm64|x86_64) ;;
    *) printf 'Arquitetura não suportada: %s\n' "$BEIRA_ARCH" >&2; exit 1 ;;
esac
BEIRA_OUTPUT="${BEIRA_OUTPUT_DIR:-$BEIRA_ROOT/build}"
swift build -c release --arch "$BEIRA_ARCH" --scratch-path "$BEIRA_ROOT/.build/$BEIRA_ARCH"
BEIRA_BIN="$(swift build -c release --arch "$BEIRA_ARCH" --scratch-path "$BEIRA_ROOT/.build/$BEIRA_ARCH" --show-bin-path)"
BEIRA_APP="$BEIRA_OUTPUT/Beira.app"
mkdir -p "$BEIRA_APP/Contents/MacOS" "$BEIRA_APP/Contents/Resources"
cp "$BEIRA_BIN/Beira" "$BEIRA_APP/Contents/MacOS/Beira"
cp Resources/Info.plist "$BEIRA_APP/Contents/Info.plist"
cp THIRD_PARTY_NOTICES.md "$BEIRA_APP/Contents/Resources/ThirdPartyNotices.txt"
swift scripts/make-icon.swift "$BEIRA_OUTPUT"
iconutil -c icns "$BEIRA_OUTPUT/Beira.iconset" -o "$BEIRA_APP/Contents/Resources/Beira.icns"
# Use a configured signing identity to keep the app's identity across rebuilds.
BEIRA_SIGNER="${BEIRA_SIGN_IDENTITY:-}"
if [[ "${BEIRA_SIGN_MODE:-configured}" == "adhoc" ]]; then
    BEIRA_SIGNER=""
elif [[ -z "$BEIRA_SIGNER" && -f "$BEIRA_ROOT/.signing-identity" ]]; then
    BEIRA_SIGNER="$(cat "$BEIRA_ROOT/.signing-identity")"
fi
if [[ -n "$BEIRA_SIGNER" ]]; then
    codesign --force --options runtime --sign "$BEIRA_SIGNER" "$BEIRA_APP"
else
    codesign --force --sign - --timestamp=none --identifier com.arthurbenfica.beira "$BEIRA_APP"
fi
codesign --verify --strict "$BEIRA_APP"
lipo -verify_arch "$BEIRA_ARCH" "$BEIRA_APP/Contents/MacOS/Beira"
printf 'Aplicativo pronto: %s\n' "$BEIRA_APP"
