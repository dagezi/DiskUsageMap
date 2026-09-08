#!/bin/bash
# Builds the SPM executable and packages it into a proper DiskUsageMap.app
# bundle, so LaunchServices treats it as a normal app (Dock icon, Cmd+Tab,
# double-clickable/`open`-able) instead of guessing at an unbundled binary's
# status the way `swift run`/the raw .build binary does.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-debug}"
APP_NAME="DiskUsageMap"
BUNDLE_ID="com.dagezi.DiskUsageMap"

if [ "$CONFIG" = "release" ]; then
    swift build -c release
    BUILT_BINARY=".build/release/$APP_NAME"
else
    swift build
    BUILT_BINARY=".build/debug/$APP_NAME"
fi

APP_BUNDLE="$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILT_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper doesn't complain on launch, and so the bundle ID
# gives it a stable identity across rebuilds (TCC/permission grants like Full
# Disk Access key off this instead of re-prompting for every unsigned binary).
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
