#!/bin/bash

# Build and install ClaudeCodeMonitor to /Applications

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeCodeMonitor"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"
INSTALL_DIR="/Applications"

# Build first
"${SCRIPT_DIR}/build-app.sh"

echo ""
echo "Installing to ${INSTALL_DIR}..."

# Remove old version if exists
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    echo "Removing previous version..."
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

# Copy to /Applications
cp -R "${APP_BUNDLE}" "${INSTALL_DIR}/${APP_NAME}.app"

echo ""
echo "Installed: ${INSTALL_DIR}/${APP_NAME}.app"
echo ""
echo "You can now:"
echo "  1. Open from Spotlight: search 'Claude Code Monitor'"
echo "  2. Open from terminal:  open /Applications/${APP_NAME}.app"
echo "  3. Enable 'Launch at Login' in the app's Settings"
