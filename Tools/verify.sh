#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"
mkdir -p replica/verification
swift run PokerCoreChecks > replica/verification/core-checks.txt 2>&1
cat replica/verification/core-checks.txt
swift test -c release > replica/verification/unit-tests.txt 2>&1
cat replica/verification/unit-tests.txt
SWIFT_BIN=$(swift build --show-bin-path)
plutil -lint PokerTrainer.xcodeproj/project.pbxproj
if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
  xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer \
    -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build \
    > replica/verification/ios-build.txt 2>&1
  echo "iOS Simulator build completed."
else
  echo "Full Xcode/iOS SDK unavailable; checking the same SwiftUI sources against the macOS SDK."
  swiftc -typecheck -parse-as-library -strict-concurrency=complete \
    -I "$SWIFT_BIN" -I "$SWIFT_BIN/Modules" App/Persistence/PracticeStore.swift \
    App/Application/*.swift App/UI/*.swift App/PokerTrainerApp.swift \
    > replica/verification/swiftui-typecheck.txt 2>&1
  echo "macOS SwiftUI typecheck passed. iOS Simulator execution remains unverified."
fi

# Support both SwiftPM build layouts (Swift 6.3 and Swift 6.4 Swift Build).
if [ -f "$SWIFT_BIN/PokerCore.o" ]; then
  set -- "$SWIFT_BIN/PokerCore.o"
else
  set -- "$SWIFT_BIN"/PokerCore.build/*.swift.o
fi
# Application model and actual persistence integration on the available macOS SDK.
swiftc -parse-as-library -strict-concurrency=complete -I "$SWIFT_BIN" -I "$SWIFT_BIN/Modules" \
  App/Persistence/PracticeStore.swift App/Application/*.swift Tools/AppChecks.swift \
  "$@" -o .build/app-checks
.build/app-checks "$PROJECT_ROOT/.build" > replica/verification/app-checks.txt 2>&1
.build/app-checks "$PROJECT_ROOT/.build" --reload-regression >> replica/verification/app-checks.txt 2>&1
cat replica/verification/app-checks.txt
