#!/usr/bin/env bash
# A real device build, with signing deferred to the owner's Linux sideloading app.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This build requires macOS and Xcode. Run the iOS unsigned IPA GitHub workflow.' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/ios-artifacts"
BUILD_DIR="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/opengym-ios.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$OUT"
trap 'printf "Failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND" | tee "$OUT/build-error.log" >&2' ERR

xcodebuild -version
pod --version
cd "$ROOT/frontend"
npm ci 2>&1 | tee "$OUT/npm-install.log"
npm test 2>&1 | tee "$OUT/frontend-tests.log"
# Includes repository exercise media, cap sync / pod install, and bundle validation.
npm run build:mobile 2>&1 | tee "$OUT/mobile-build.log"

VERSION="$(node -p "require('./package.json').version")"
BUILD="$(sed -n 's/^ *versionCode \([0-9]*\).*/\1/p' android/app/build.gradle | head -n 1)"
[[ -n "$BUILD" ]] || { echo 'Android versionCode is missing' >&2; exit 1; }

cd ios/App
xcodebuild -workspace App.xcworkspace -scheme App -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$BUILD_DIR/App.xcarchive" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  archive 2>&1 | tee "$OUT/xcodebuild.log"

APP="$BUILD_DIR/App.xcarchive/Products/Applications/App.app"
test -f "$APP/Info.plist"
test -f "$APP/public/index.html"
test -f "$APP/public/exercise-media/NOTICE.md"
test -z "$(find "$APP" -name embedded.mobileprovision -print -quit)"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
lipo "$APP/$EXECUTABLE" -verify_arch arm64

mkdir "$BUILD_DIR/Payload"
ditto "$APP" "$BUILD_DIR/Payload/App.app"
cd "$BUILD_DIR"
IPA="openGym-$VERSION-unsigned.ipa"
/usr/bin/zip -qry "$OUT/$IPA" Payload
/usr/bin/unzip -tq "$OUT/$IPA"
cd "$OUT"
shasum -a 256 "$IPA" > "$IPA.sha256"
{
  echo "openGym version: $VERSION ($BUILD)"
  echo "Source commit: $(git -C "$ROOT" rev-parse HEAD)"
  echo "Signing: unsigned; sign locally before installation"
  xcodebuild -version
} > build-info.txt
cat build-info.txt "$IPA.sha256"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo '### openGym iPhone build'
    echo "Version: $VERSION ($BUILD)"
    echo
    echo 'Download **openGym-iOS-unsigned** from this run. Extract it, then use iloader on Linux to sign and install the IPA with your Apple Account.'
    echo 'Apple credentials and signing certificates are not needed by this workflow.'
  } >> "$GITHUB_STEP_SUMMARY"
fi
