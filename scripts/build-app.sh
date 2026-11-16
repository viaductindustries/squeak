#!/bin/bash
# Builds Squeak.app into ./build.
# Usage: scripts/build-app.sh [--install] [--universal]
#   --install    also copy the app to /Applications and open it
#   --universal  build for both Apple Silicon and Intel
# The version comes from version.txt (maintained by Release Please); the build number from $BUILD_NUMBER or the git commit count.
# Signs with $SIGN_ID, or else the first Apple Development identity in the keychain, or else ad hoc.
# A real identity keeps the Accessibility permission across rebuilds; release builds are re-signed by notarize-app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=false
BUILD_ARGS=(-c release)
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        --universal) BUILD_ARGS+=(--arch arm64 --arch x86_64) ;;
        *) echo "Unknown option: $arg" >&2; exit 64 ;;
    esac
done

VERSION="$(tr -d '[:space:]' < version.txt)"
BUILD="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

swift build "${BUILD_ARGS[@]}"
BIN="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/Squeak"

APP="build/Squeak.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Squeak"
cp Support/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"

# actool needs absolute paths: its helper resolves relative ones against another directory.
xcrun actool "$PWD/Support/AppIcon.icon" --compile "$PWD/$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 15.0 --app-icon AppIcon \
    --output-partial-info-plist "$PWD/build/icon-info.plist" > /dev/null

SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -n 1)}"
codesign --force --options runtime --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP (version $VERSION, build $BUILD, signed by ${SIGN_ID:-ad hoc})"

if $INSTALL; then
    # Quit the running copy first, so the new one is what opens.
    pkill -x Squeak || true
    for _ in {1..50}; do pgrep -x Squeak > /dev/null || break; sleep 0.1; done
    rm -rf /Applications/Squeak.app
    cp -R "$APP" /Applications/
    open /Applications/Squeak.app
    echo "Installed to /Applications/Squeak.app"
fi
