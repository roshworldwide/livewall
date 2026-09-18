#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-Release}"
PROJECT="$ROOT/LiveWall.xcodeproj"
SCHEME="LiveWall"
DERIVED="$ROOT/build"
DIST="$ROOT/dist"

MAKE_DMG=1
REVEAL=0
for arg in "$@"; do
    case "$arg" in
        --no-dmg) MAKE_DMG=0 ;;
        --reveal) REVEAL=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1m── %s\033[0m\n' "$1"; }
die()  { printf '\n\033[31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }

step "Preflight"

[ "$(uname -s)" = "Darwin" ] || die "LiveWall is a macOS app — this only builds on macOS."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found. Install Xcode from the App Store and open it once."

DEVDIR="$(xcode-select -p 2>/dev/null || true)"
case "$DEVDIR" in
    *CommandLineTools*)
        die "Command Line Tools are selected instead of full Xcode.
       Fix:  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        ;;
esac

if xcodebuild -version 2>&1 | grep -qi "license"; then
    die "The Xcode licence has not been accepted.
       Fix:  sudo xcodebuild -license accept"
fi

echo "macOS:  $(sw_vers -productVersion) ($(uname -m))"
echo "Xcode:  $(xcodebuild -version | head -1)"
echo "Config: $CONFIGURATION"
[ -d "$PROJECT" ] || die "LiveWall.xcodeproj not found in $ROOT"

step "Compiling"

rm -rf "$DERIVED" "$DIST"
mkdir -p "$DIST"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM="" \
    ONLY_ACTIVE_ARCH=NO \
    build

APP="$DERIVED/Build/Products/$CONFIGURATION/LiveWall.app"
[ -d "$APP" ] || die "Build reported success but no app was produced at $APP"

VERSION="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo 1.0)"
echo "Built LiveWall $VERSION"

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" 2>/dev/null || true
codesign --verify "$APP" || die "Ad-hoc signature failed verification"

cp -R "$APP" "$DIST/LiveWall.app"

if [ "$MAKE_DMG" -eq 0 ]; then
    step "Done (skipped DMG)"
    echo "$DIST/LiveWall.app"
    exit 0
fi

step "Packaging DMG"

STAGE="$DIST/stage"
DMG="$DIST/LiveWall-$VERSION.dmg"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/LiveWall.app"
ln -s /Applications "$STAGE/Applications"

ICNS="$(/usr/bin/find "$APP/Contents/Resources" -maxdepth 1 -name '*.icns' 2>/dev/null | head -1)"
if [ -n "$ICNS" ]; then
    cp "$ICNS" "$STAGE/.VolumeIcon.icns"
    /usr/bin/SetFile -a C "$STAGE" 2>/dev/null || true
fi

rm -f "$DMG"
hdiutil create \
    -volname "LiveWall" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -quiet \
    "$DMG"

rm -rf "$STAGE"
[ -f "$DMG" ] || die "hdiutil did not produce a disk image"

step "Verifying"
hdiutil verify "$DMG" >/dev/null 2>&1 || die "Disk image failed verification"
shasum -a 256 "$DMG" | tee "$DMG.sha256"

printf '\n\033[32m✓ %s (%s)\033[0m\n' "$DMG" "$(du -h "$DMG" | cut -f1 | tr -d ' ')"

[ "$REVEAL" -eq 1 ] && open -R "$DMG" 2>/dev/null
exit 0
