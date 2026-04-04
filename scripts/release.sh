#!/bin/bash
# CodeIsland Release Script
# Usage: ./scripts/release.sh v1.9.0

set -e

VERSION="${1:?Usage: $0 <version>}"
TEAM_ID="4GT6V2DUTF"
SIGN_IDENTITY="Developer ID Application: Wuxi Wudao Matrix Information Technology Co., Ltd ($TEAM_ID)"
KEYCHAIN_PROFILE="CodeIsland"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/ClaudeIsland-guzapwxyhrxjvgdvqogvkpjqjwht/Build/Products/Release"
APP_PATH="$BUILD_DIR/Code Island.app"
ZIP_PATH="$PROJECT_DIR/CodeIsland-${VERSION}.zip"

echo "=== CodeIsland Release $VERSION ==="

# 0. Update version in Xcode project
CLEAN_VERSION="${VERSION#v}"  # Remove 'v' prefix: v1.8.1 -> 1.8.1
echo ">>> Setting version to $CLEAN_VERSION..."
sed -i '' "s/MARKETING_VERSION = [0-9.]*/MARKETING_VERSION = $CLEAN_VERSION/g" \
  "$PROJECT_DIR/ClaudeIsland.xcodeproj/project.pbxproj"

# 1. Build
echo ">>> Building Release..."
cd "$PROJECT_DIR"
xcodebuild -scheme ClaudeIsland -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" 2>&1 | tail -1

# 2. Sign
echo ">>> Signing with Developer ID..."
codesign --deep --force --options runtime \
  --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
echo "    Signature verified."

# 3. Package
echo ">>> Packaging..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "    $(du -h "$ZIP_PATH" | cut -f1)"

# 4. Notarize
echo ">>> Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" --wait

# 5. Staple
echo ">>> Stapling ticket..."
xcrun stapler staple "$APP_PATH"

# 6. Re-package with stapled ticket
echo ">>> Re-packaging with notarization ticket..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# 7. Git tag
echo ">>> Tagging $VERSION..."
git add -A
git commit -m "$VERSION: Release" --allow-empty || true
git tag "$VERSION"

echo ""
echo "=== Done! ==="
echo "Signed + notarized package: $ZIP_PATH"
echo ""
echo "Next steps:"
echo "  git push origin main --tags"
echo "  gh release create $VERSION $ZIP_PATH --title \"$VERSION\""
