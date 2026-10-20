#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
APP_NAME="MandelbulberMac"
BUNDLE_ID="org.mandelbulber.native-preview"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/native/MandelbulberMac"
APP_BUNDLE="$PACKAGE_DIR/dist/$APP_NAME.app"
case "$MODE" in
  run|--verify|--logs|--telemetry|--debug) ;;
  *) echo "usage: $0 [run|--verify|--logs|--telemetry|--debug]" >&2; exit 2 ;;
esac
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build --package-path "$PACKAGE_DIR"
BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_BUNDLE/Contents/Resources/"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
case "$MODE" in
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
esac
