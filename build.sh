#!/bin/bash
# Builds build/CapsNumber.app as a universal binary (Apple Silicon + Intel).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/CapsNumber.app"
MIN_OS="13.0"

rm -rf build
mkdir -p "$APP/Contents/MacOS" build/arch

for arch in arm64 x86_64; do
    swiftc -O -swift-version 5 \
        -target "$arch-apple-macosx$MIN_OS" \
        -framework Carbon \
        -o "build/arch/CapsNumber-$arch" \
        Sources/main.swift
done
lipo -create build/arch/CapsNumber-arm64 build/arch/CapsNumber-x86_64 \
    -output "$APP/Contents/MacOS/CapsNumber"
rm -rf build/arch

cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null 2>&1

echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/CapsNumber"))"
