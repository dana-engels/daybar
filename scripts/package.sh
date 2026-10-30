#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release "$@"
mkdir -p dist/Daybar.app/Contents/MacOS
cp .build/release/Daybar dist/Daybar.app/Contents/MacOS/Daybar.new
mv -f dist/Daybar.app/Contents/MacOS/Daybar.new dist/Daybar.app/Contents/MacOS/Daybar
cat > dist/Daybar.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Daybar</string>
<key>CFBundleIdentifier</key><string>local.daybar.app</string>
<key>CFBundleExecutable</key><string>Daybar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - dist/Daybar.app
printf 'Built dist/Daybar.app\n'
