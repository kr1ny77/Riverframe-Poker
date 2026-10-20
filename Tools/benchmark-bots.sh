#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build
DEVICE_ID=${1:-54714A01-B621-4D35-9778-94E20E84AFB6}
xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/bot-performance CODE_SIGNING_ALLOWED=NO build > .build/bot-performance-build.log 2>&1
PRODUCTS=.build/bot-performance/Build/Products/Release-iphonesimulator
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -O -parse-as-library -swift-version 6 -sdk "$SDK_PATH" \
  -target arm64-apple-ios17.0-simulator -I "$PRODUCTS" Tools/BotBenchmark.swift \
  "$PRODUCTS/PokerCore.o" -o .build/bot-benchmark
if ! xcrun simctl list devices booted | rg -q "$DEVICE_ID"; then
  xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl spawn "$DEVICE_ID" "$PWD/.build/bot-benchmark"
