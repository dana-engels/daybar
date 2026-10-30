#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release "$@"
bin_dir=$(swift build -c release --show-bin-path "$@")
mkdir -p dist
stage=$(mktemp -d dist/.daybar-stage.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/Daybar.app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/Daybar" "$app/Contents/MacOS/Daybar"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Daybar</string>
<key>CFBundleIdentifier</key><string>local.daybar.app</string>
<key>CFBundleExecutable</key><string>Daybar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
# Replace the last app only after the complete new bundle is verified.
if [ -e dist/Daybar.app ]; then mv dist/Daybar.app "$stage/Previous.app"; fi
if ! mv "$app" dist/Daybar.app; then
    if [ -e "$stage/Previous.app" ]; then mv "$stage/Previous.app" dist/Daybar.app; fi
    exit 1
fi
printf 'Built dist/Daybar.app\n'
