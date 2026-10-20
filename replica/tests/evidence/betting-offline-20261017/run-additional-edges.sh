#!/bin/sh
set -eu
cd /Users/kr1ny77/Desktop/Poker
QA_DEVICE=$(xcrun simctl create 'Poker QA Betting Edges' com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-27-0)
cleanup() {
  xcrun simctl shutdown "$QA_DEVICE" >/dev/null 2>&1 || :
  xcrun simctl delete "$QA_DEVICE" >/dev/null 2>&1 || :
}
trap cleanup EXIT
printf 'Additional QA device: %s\n' "$QA_DEVICE"
xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer \
 -destination "platform=iOS Simulator,id=$QA_DEVICE" -derivedDataPath .build/ui-qa \
 -resultBundlePath replica/tests/evidence/betting-offline-20261017/additional-edges.xcresult \
 -parallel-testing-enabled NO -collect-test-diagnostics never \
 -only-testing:PokerTrainerUITests/CriticalFlows/testShortStackCallAllIn \
 -only-testing:PokerTrainerUITests/CriticalFlows/testAllInAfterBlindContribution \
 CODE_SIGNING_ALLOWED=NO test > replica/tests/evidence/betting-offline-20261017/additional-edges.txt 2>&1
xcrun xcresulttool get test-results summary --path replica/tests/evidence/betting-offline-20261017/additional-edges.xcresult > replica/tests/evidence/betting-offline-20261017/additional-summary.json
xcrun xcresulttool export attachments --path replica/tests/evidence/betting-offline-20261017/additional-edges.xcresult --output-path replica/tests/evidence/betting-offline-20261017/additional-screens --filter '*.png'
printf 'PASS: short all-in call and existing blind contribution\n'
