#!/usr/bin/env bash
set -euo pipefail

swift build -c release "$@"
APP="dist/MacRuleManager.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/MacRuleManager "$APP/Contents/MacOS/MacRuleManager"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Mac Rule Manager</string>
<key>CFBundleDisplayName</key><string>规则管家</string>
<key>CFBundleIdentifier</key><string>org.macrulemanager.app</string>
<key>CFBundleExecutable</key><string>MacRuleManager</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
echo "Built $APP"
