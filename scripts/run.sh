#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/app_identity.sh"

echo "🚀 Starting $MAC_APP_PRODUCT_NAME..."

# Kill any existing instance
pkill -x "$MAC_APP_EXECUTABLE" 2>/dev/null || true
sleep 0.3

# Check if app bundle exists
if [ -d "$ROOT_DIR/$MAC_APP_BUNDLE_NAME" ]; then
    echo "  Opening $MAC_APP_BUNDLE_NAME..."
    open "$ROOT_DIR/$MAC_APP_BUNDLE_NAME"
elif [ -f "$ROOT_DIR/MacHost/.build/release/SideScreen" ]; then
    echo "  Running release binary..."
    "$ROOT_DIR/MacHost/.build/release/SideScreen" &
elif [ -f "$ROOT_DIR/MacHost/.build/debug/SideScreen" ]; then
    echo "  Running debug binary..."
    "$ROOT_DIR/MacHost/.build/debug/SideScreen" &
else
    echo "❌ No build found. Building now..."
    "$SCRIPT_DIR/build_mac.sh"
    echo ""
    echo "  Opening $MAC_APP_BUNDLE_NAME..."
    open "$ROOT_DIR/$MAC_APP_BUNDLE_NAME"
fi

echo ""
echo "✅ Mac app started!"
echo ""

# Setup USB if device connected
if adb devices 2>/dev/null | grep -q "device$"; then
    echo "📱 Android device detected, setting up USB..."
    adb reverse --remove tcp:54321 2>/dev/null || true
    adb reverse tcp:54321 tcp:54321
    echo "  ✓ Port forwarding ready"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Open 'SideScreen Flow' on Android and tap Connect"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
