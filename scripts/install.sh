#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/app_identity.sh"

echo "Installing $MAC_APP_PRODUCT_NAME..."

if ! adb devices | grep -q "device$"; then
    echo "No authorized Android device found via ADB."
    echo "Connect the tablet, enable USB debugging, and approve this Mac."
    exit 1
fi

"$SCRIPT_DIR/build_mac.sh"
"$SCRIPT_DIR/build_android.sh"
"$SCRIPT_DIR/install_android.sh"

echo
echo "Installation complete."
echo "Start the Mac host with: ./scripts/run.sh"
echo "Then open SideScreen Flow on Android and tap Connect."
echo "With Auto-start streaming enabled, the Mac server starts when the app opens."
