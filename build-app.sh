#!/bin/bash
# Build MD Preview as a macOS .app bundle
# Usage: bash build-app.sh [/path/to/index.html] [app-name]
#
# Reusable: packages any single HTML file as a macOS Dock app
# Default: packages md-preview/index.html as "MD Preview.app"

set -e

HTML_SRC="${1:-$(dirname "$0")/index.html}"
APP_NAME="${2:-MD Preview}"
APP_DIR="/Applications/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

if [ ! -f "$HTML_SRC" ]; then
  echo "❌ HTML file not found: $HTML_SRC"
  exit 1
fi

# Kill running instance if any
pkill -f "${APP_NAME}.app/Contents/MacOS/launcher" 2>/dev/null || true
sleep 1

# Remove previous install completely
if [ -d "$APP_DIR" ]; then
  echo "🗑️  Removing old ${APP_NAME}.app..."
  rm -rf "$APP_DIR"
fi

mkdir -p "$MACOS" "$RESOURCES"

# Copy HTML
cp "$HTML_SRC" "$RESOURCES/index.html"

# Copy icon if it exists
ICON_SRC="$(dirname "$0")/icon.icns"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$RESOURCES/AppIcon.icns"
fi

# Create launcher
cat > "$MACOS/launcher" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"

if [ -n "$1" ] && [ -f "$1" ]; then
  # File argument provided - serve it via HTTP server
  FILE_DIR="$(dirname "$1")"
  FILE_NAME="$(basename "$1")"
  PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('', 0)); print(s.getsockname()[1]); s.close()")
  
  # Start HTTP server in background
  cd "$FILE_DIR"
  python3 -m http.server "$PORT" > /dev/null 2>&1 &
  SERVER_PID=$!
  
  # Open Chrome with file parameter
  HTML="file://${DIR}/index.html?file=${FILE_NAME}&port=${PORT}"
  
  # Kill server after 30 seconds
  (sleep 30; kill $SERVER_PID 2>/dev/null) &
else
  # No file argument - open normally
  HTML="file://${DIR}/index.html"
fi

if [ -d "/Applications/Google Chrome.app" ]; then
  open -na "Google Chrome" --args --app="$HTML"
elif [ -d "/Applications/Safari.app" ]; then
  open -a Safari "$HTML"
else
  open "$HTML"
fi
EOF
chmod +x "$MACOS/launcher"

# Bundle ID from app name
BUNDLE_ID="com.marketingbull.$(echo "$APP_NAME" | tr '[:upper:] ' '[:lower:]-')"

# Info.plist
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>launcher</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Markdown Document</string>
            <key>CFBundleTypeExtensions</key>
            <array><string>md</string><string>markdown</string><string>mmd</string></array>
            <key>CFBundleTypeRole</key><string>Editor</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Strip quarantine
xattr -cr "$APP_DIR" 2>/dev/null || true

echo "✅ ${APP_NAME}.app installed to /Applications/"
echo "   Pin to Dock: right-click → Options → Keep in Dock"
echo "   Other Macs: xattr -cr \"${APP_DIR}\""
