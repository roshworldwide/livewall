#!/bin/bash
#
#  Build LiveWall.command
#
#  Double-click in Finder. Compiles LiveWall and packages dist/LiveWall-<version>.dmg.
#  Everything printed here is also written to build.log next to this file.
#
#  This is a thin wrapper — the real work lives in Scripts/build.sh so that CI
#  and the command line run exactly the same path.
#

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

LOG="$DIR/build.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  LiveWall — build & package"
echo "  $(date)"
echo "════════════════════════════════════════════════════════════"

bash "$DIR/Scripts/build.sh" --reveal
RC=$?

if [ $RC -ne 0 ]; then
    echo
    echo "════════════════════════════════════════════════════════════"
    echo "  BUILD FAILED (exit $RC)"
    echo
    echo "  Compiler errors, if any:"
    grep -E "error:" "$LOG" | sed 's/^/    /' | head -20
    echo
    echo "  Full output: $LOG"
    echo "════════════════════════════════════════════════════════════"
    exit $RC
fi

echo
echo "════════════════════════════════════════════════════════════"
echo "  BUILD SUCCEEDED"
echo "  Open the DMG and drag LiveWall into Applications."
echo "════════════════════════════════════════════════════════════"
