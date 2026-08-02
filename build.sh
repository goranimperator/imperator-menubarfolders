#!/bin/bash
set -euo pipefail

APP_NAME="MenuBarFolders"
APP_BUNDLE="Imperator MenuBarFolders.app"

echo "Building ${APP_NAME}..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"

echo "Signing app bundle..."
codesign --sign - --force --deep "${APP_BUNDLE}"

echo "Installing to /Applications..."
rm -rf "/Applications/${APP_BUNDLE}"
cp -R "${APP_BUNDLE}" "/Applications/${APP_BUNDLE}"

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo "Installed to: /Applications/${APP_BUNDLE}"
echo "Run with: open '/Applications/${APP_BUNDLE}'"
