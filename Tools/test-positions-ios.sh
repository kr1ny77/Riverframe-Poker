#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
QA_OUTPUT="replica/tests/evidence/positions-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$QA_OUTPUT"
QA_DEVICE=$(xcrun simctl create 'Poker QA Positions iPhone17e' com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-27-0)
cleanup() {
  xcrun simctl shutdown "$QA_DEVICE" >/dev/null 2>&1 || :
  xcrun simctl delete "$QA_DEVICE" >/dev/null 2>&1 || :
}
trap cleanup EXIT
printf 'Evidence: %s\n' "$QA_OUTPUT"
xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer \
  -destination "platform=iOS Simulator,id=$QA_DEVICE" -derivedDataPath .build/ui-qa \
  -resultBundlePath "$QA_OUTPUT/flows.xcresult" -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -only-testing:PokerTrainerUITests/CriticalFlows/testPositionsLessonAndRelaunch \
  CODE_SIGNING_ALLOWED=NO test > "$QA_OUTPUT/flows.txt" 2>&1
xcrun xcresulttool export attachments --path "$QA_OUTPUT/flows.xcresult" --output-path "$QA_OUTPUT/screenshots" > "$QA_OUTPUT/screenshots.txt" 2>&1
printf 'PASS: positions lesson and restored progress.\n'
