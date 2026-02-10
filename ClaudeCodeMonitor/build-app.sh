#!/bin/bash

# Build ClaudeCodeMonitor as a macOS .app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeCodeMonitor"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"
INFO_PLIST="${SCRIPT_DIR}/${APP_NAME}/Info.plist"

echo "Building ${APP_NAME} (release)..."
cd "${SCRIPT_DIR}"
swift build -c release

echo "Creating .app bundle..."

# Clean previous bundle
rm -rf "${APP_BUNDLE}"

# Create bundle directory structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${INFO_PLIST}" "${APP_BUNDLE}/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Ad-hoc code sign (required for SMAppService / Launch at Login)
echo "Code signing..."
codesign --force --sign - --deep "${APP_BUNDLE}"

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo ""
echo "To run:    open ${APP_BUNDLE}"
echo "To install: ./install.sh"
