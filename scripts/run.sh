#!/bin/bash
set -euo pipefail
BEIRA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$BEIRA_ROOT/scripts/build.sh"
open "$BEIRA_ROOT/build/Beira.app"
