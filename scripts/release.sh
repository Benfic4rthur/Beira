#!/bin/bash
# Local builds only. Does not install apps, publish, or invoke GitHub Actions.
set -euo pipefail
BEIRA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BEIRA_ROOT"
BEIRA_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
BEIRA_RELEASE="$BEIRA_ROOT/build/releases/v$BEIRA_VERSION"
mkdir -p "$BEIRA_RELEASE"
for BEIRA_CPU in arm64 x86_64; do
    if [[ "$BEIRA_CPU" == arm64 ]]; then BEIRA_LABEL=AppleSilicon; else BEIRA_LABEL=Intel; fi
    BEIRA_STAGE="$BEIRA_RELEASE/$BEIRA_CPU"
    BEIRA_ARCH="$BEIRA_CPU" BEIRA_SIGN_MODE=adhoc BEIRA_OUTPUT_DIR="$BEIRA_STAGE" ./scripts/build.sh
    BEIRA_ZIP="$BEIRA_RELEASE/Beira-$BEIRA_LABEL.zip"
    ditto -c -k --sequesterRsrc --keepParent "$BEIRA_STAGE/Beira.app" "$BEIRA_ZIP"
done
cd "$BEIRA_RELEASE"
shasum -a 256 Beira-AppleSilicon.zip Beira-Intel.zip > SHA256SUMS.txt
printf 'Downloads prontos em %s\n' "$BEIRA_RELEASE"
