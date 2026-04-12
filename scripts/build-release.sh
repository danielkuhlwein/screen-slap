#!/bin/bash
set -euo pipefail

# Screen Slap — build, sign, notarise, package, and optionally publish a release
#
# Usage:
#   ./scripts/build-release.sh <version>            # build only
#   ./scripts/build-release.sh <version> --publish   # build + GitHub Release
#
# Prerequisites:
#   - Xcode with "Developer ID Application" certificate installed
#   - Notarytool credentials stored in keychain (one-time):
#       xcrun notarytool store-credentials "screen-slap" \
#           --apple-id "your@email.com" \
#           --team-id "WG7BK7C4BG" \
#           --password "app-specific-password"
#
# Examples:
#   ./scripts/build-release.sh 1.0.0
#   ./scripts/build-release.sh 1.0.0 --publish

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <version> [--publish]"
    echo "  version: semver like 1.0.0"
    echo "  --publish: create GitHub Release and upload DMG"
    exit 1
fi

VERSION="$1"
PUBLISH="${2:-}"
APP_NAME="Screen Slap"
PRODUCT_NAME="Screen Slap"
SCHEME="screen-slap"
BUILD_DIR="build/release"
APP_PATH="$BUILD_DIR/$PRODUCT_NAME.app"
DMG_PATH="build/ScreenSlap-${VERSION}.dmg"
TAG="v${VERSION}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-screen-slap}"
DEVELOPMENT_TEAM="WG7BK7C4BG"
SIGN_IDENTITY="Developer ID Application"

# Verify the signing identity exists
if ! security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    echo "Error: No '$SIGN_IDENTITY' certificate found."
    echo "  Install it from your Apple Developer account (Certificates, Identifiers & Profiles)."
    exit 1
fi

# Sparkle tools (resolved via SPM into Xcode DerivedData)
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Sparkle*/bin/generate_appcast" -type f 2>/dev/null | head -1)
SIGN_UPDATE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Sparkle*/bin/sign_update" -type f 2>/dev/null | head -1)

echo "==> Building $APP_NAME v$VERSION"
echo "    Team: $DEVELOPMENT_TEAM"

# Set version in Xcode project (MARKETING_VERSION = semver, CURRENT_PROJECT_VERSION = auto-increment build number)
CURRENT_BUILD=$(grep -c "CURRENT_PROJECT_VERSION" screen-slap.xcodeproj/project.pbxproj 2>/dev/null || echo "0")
# Read the current build number from the first occurrence
CURRENT_BUILD_NUM=$(grep -m1 "CURRENT_PROJECT_VERSION" screen-slap.xcodeproj/project.pbxproj | sed 's/.*= *\([0-9]*\).*/\1/')
NEXT_BUILD_NUM=$((CURRENT_BUILD_NUM + 1))

echo "    Marketing version: $VERSION (build $NEXT_BUILD_NUM)"
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" screen-slap.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $NEXT_BUILD_NUM/" screen-slap.xcodeproj/project.pbxproj

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build release (xcodebuild handles signing with hardened runtime)
xcodebuild \
    -project screen-slap.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CONFIGURATION_BUILD_DIR="$(pwd)/$BUILD_DIR" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    build

echo "==> Built $APP_PATH"

# Re-sign all embedded binaries with Developer ID + timestamp + hardened runtime.
# xcodebuild signs the main binary but SPM-built dependencies (Sparkle) may not
# inherit the correct signing identity or timestamp.
echo "==> Signing embedded frameworks and helpers"

# Find and sign every Mach-O binary inside Frameworks (innermost first via -depth)
find "$APP_PATH/Contents/Frameworks" -depth \( -name "*.xpc" -o -name "*.app" -o -name "*.framework" \) -type d | while read -r bundle; do
    echo "    Signing $(basename "$bundle")"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp --options runtime "$bundle"
done

# Also sign any standalone Mach-O executables not inside sub-bundles (e.g. Sparkle's Autoupdate)
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
find "$FRAMEWORKS_DIR" -type f | while read -r bin; do
    # Get path relative to Frameworks dir; skip files inside .app or .xpc sub-bundles
    rel_path="${bin#"$FRAMEWORKS_DIR"/}"
    if echo "$rel_path" | grep -qE '\.(app|xpc)/'; then
        continue
    fi
    if file "$bin" | grep -q "Mach-O"; then
        echo "    Signing $(basename "$bin")"
        codesign --force --sign "$SIGN_IDENTITY" --timestamp --options runtime "$bin"
    fi
done

# Re-sign frameworks after signing their contents
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -type d -maxdepth 1 | while read -r fw; do
    echo "    Re-signing $(basename "$fw")"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp --options runtime "$fw"
done

# Sign the main app bundle (outermost — must be last)
echo "    Signing $PRODUCT_NAME.app"
codesign --force --sign "$SIGN_IDENTITY" --timestamp --options runtime \
    --entitlements screen-slap/screen-slap.entitlements "$APP_PATH"

# Verify code signature
echo "==> Verifying code signature"
codesign --verify --deep --strict "$APP_PATH"
codesign -d --verbose=2 "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier"
echo "==> Signature valid"

# Create DMG
if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-size 600 400 \
        --icon "$PRODUCT_NAME.app" 150 200 \
        --app-drop-link 450 200 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_PATH"
else
    echo "==> create-dmg not found, using hdiutil fallback"
    echo "    Install with: brew install create-dmg"

    STAGING="$BUILD_DIR/dmg-staging"
    mkdir -p "$STAGING"
    cp -R "$APP_PATH" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"

    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    rm -rf "$STAGING"
fi

echo "==> Created $DMG_PATH"

# Sign the DMG
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
echo "==> Signed DMG"

# Notarise
echo "==> Submitting for notarisation (this may take a few minutes)..."
NOTARIZE_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait 2>&1) || true
echo "$NOTARIZE_OUTPUT"

if echo "$NOTARIZE_OUTPUT" | grep -q "status: Accepted"; then
    echo "==> Notarisation accepted"
else
    echo "Error: Notarisation failed. Check the log with:"
    SUBMISSION_ID=$(echo "$NOTARIZE_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    echo "  xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARYTOOL_PROFILE"
    exit 1
fi

# Staple the notarisation ticket to the DMG
xcrun stapler staple "$DMG_PATH"
echo "==> Stapled notarisation ticket"

# Verify notarisation
echo "==> Verifying notarisation"
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"
echo "==> Notarisation verified"

# Generate / update appcast.xml
if [ -n "$SPARKLE_BIN" ]; then
    echo "==> Generating appcast.xml"
    APPCAST_DIR="build/appcast"
    mkdir -p "$APPCAST_DIR"
    cp "$DMG_PATH" "$APPCAST_DIR/"

    # generate_appcast signs each DMG and writes appcast.xml into the same dir
    "$SPARKLE_BIN" "$APPCAST_DIR" \
        --link "https://github.com/danielkuhlwein/screen-slap/releases" \
        --download-url-prefix "https://github.com/danielkuhlwein/screen-slap/releases/download/${TAG}/"

    cp "$APPCAST_DIR/appcast.xml" appcast.xml
    echo "==> appcast.xml updated"
else
    echo "Warning: generate_appcast not found — skipping appcast.xml generation."
    echo "         Build the project in Xcode first so SPM resolves Sparkle."
fi

# Publish to GitHub Releases
if [ "$PUBLISH" = "--publish" ]; then
    if ! command -v gh &>/dev/null; then
        echo "Error: gh CLI not installed. Install with: brew install gh"
        exit 1
    fi

    echo "==> Creating GitHub Release $TAG"

    NOTES="## Screen Slap v${VERSION}

### Installation
1. Download \`ScreenSlap-${VERSION}.dmg\` below
2. Open the DMG and drag **Screen Slap** to Applications
3. Launch from Applications — it lives in your menu bar!

### Setup
1. Grant calendar access when prompted
2. Screen Slap will alert you before your next meeting"

    gh release create "$TAG" \
        "$DMG_PATH" \
        --title "Screen Slap v${VERSION}" \
        --notes "$NOTES"

    echo "==> Published: $(gh release view "$TAG" --json url -q .url)"

    # Commit and push version bump + appcast.xml so Sparkle can find it
    echo "==> Committing release changes"
    git add screen-slap.xcodeproj/project.pbxproj
    if [ -f appcast.xml ]; then
        git add appcast.xml
    fi
    git commit -m "chore: release v${VERSION}"
    git push
    echo "==> Release changes pushed to main"
else
    echo ""
    echo "Release artifacts:"
    echo "  App: $APP_PATH"
    echo "  DMG: $DMG_PATH"
    echo ""
    echo "To publish to GitHub:"
    echo "  ./scripts/build-release.sh $VERSION --publish"
fi
