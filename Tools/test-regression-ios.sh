#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
QA_OUTPUT="replica/tests/evidence/regression-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$QA_OUTPUT"
QA_DEVICE=$(xcrun simctl create 'Poker QA Regression iPhone17e' com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-27-0)
cleanup() {
  xcrun simctl shutdown "$QA_DEVICE" >/dev/null 2>&1 || :
  xcrun simctl delete "$QA_DEVICE" >/dev/null 2>&1 || :
}
trap cleanup EXIT
printf 'Evidence: %s\n' "$QA_OUTPUT"
python3 Tools/prepare-offline-profile.py > "$QA_OUTPUT/network-profile.json"
QA_SINCE=$(date +%s)
QA_EXIT=0
if [ "$#" -eq 0 ]; then
  set -- testRegressionLessonCombinations testRegressionLessonOuts testRegressionLessonPotOdds testRegressionLessonKnownEquity testRegressionLessonRangeEquity testRegressionLessonPositions testRegressionLessonEV testRegressionLessonBlockers testRegressionCourseNavigation testRegressionGameplay testRegressionOffline testBetCustomAmountAndValidation testRaiseMinimum testRaiseMaximum testAllInExactConfirmation testShortStackAllInRaise testShortRaiseDoesNotReopen testShortStackCallAllIn testAllInAfterBlindContribution
fi
printf '%s\n' "$@" > "$QA_OUTPUT/selected-tests.txt"
QA_TESTS="$*"
set --
for QA_TEST in $QA_TESTS; do
  set -- "$@" "-only-testing:PokerTrainerUITests/CriticalFlows/$QA_TEST"
done
xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer \
  -destination "platform=iOS Simulator,id=$QA_DEVICE" -derivedDataPath .build/ui-qa \
  -resultBundlePath "$QA_OUTPUT/flows.xcresult" -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  "$@" \
  CODE_SIGNING_ALLOWED=NO test > "$QA_OUTPUT/flows.txt" 2>&1 || QA_EXIT=$?
xcrun xcresulttool get test-results summary --path "$QA_OUTPUT/flows.xcresult" > "$QA_OUTPUT/summary.json"
xcrun xcresulttool export attachments --path "$QA_OUTPUT/flows.xcresult" --output-path "$QA_OUTPUT/screenshots" > "$QA_OUTPUT/screenshots.txt" 2>&1
xcrun simctl boot "$QA_DEVICE" >/dev/null 2>&1 || :
xcrun simctl bootstatus "$QA_DEVICE" -b > "$QA_OUTPUT/boot.txt" 2>&1
python3 Tools/collect-offline-proof.py "$QA_DEVICE" "$QA_OUTPUT/network-proof" "$QA_SINCE" > "$QA_OUTPUT/network-proof.txt" 2>&1 || QA_EXIT=1
printf '%s\n' "$QA_EXIT" > "$QA_OUTPUT/exit-code.txt"
exit "$QA_EXIT"
