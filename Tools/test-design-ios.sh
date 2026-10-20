#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
QA_LABEL=${1:-capture}
QA_DEVICE_TYPE=${2:-com.apple.CoreSimulator.SimDeviceType.iPhone-17e}
QA_CASE=${3:-testDesignCapture}
QA_DERIVED_DATA=${4:-.build/ui-qa}
QA_OUTPUT="replica/design/evidence/$QA_LABEL-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$QA_OUTPUT"
QA_DEVICE=$(xcrun simctl create 'Poker QA Design' "$QA_DEVICE_TYPE" com.apple.CoreSimulator.SimRuntime.iOS-27-0)
cleanup() { xcrun simctl shutdown "$QA_DEVICE" >/dev/null 2>&1 || :; xcrun simctl delete "$QA_DEVICE" >/dev/null 2>&1 || :; }
trap cleanup EXIT
printf 'Evidence: %s\n' "$QA_OUTPUT"
QA_EXIT=0
if [ "$QA_CASE" = finish ]; then
  set --
  for QA_TEST in testCourseRepeatNavigationPersistenceAndGameIndependence testDesignAccessibility testDesignCapture testDesignProgressHistory testDesignRapidSubmit testDesignReducedMotion testRegressionLessonEV; do
    set -- "$@" "-only-testing:PokerTrainerUITests/CriticalFlows/$QA_TEST"
  done
elif [ "$QA_CASE" = suite ]; then
  set --
  for QA_TEST in testDesignCapture testDesignAccessibility testDesignAllLessonsXXXL testDesignProgressHistory testDesignRapidSubmit testDesignReducedMotion testComparisonLargeTextSelection testStorageFailureStillShowsPotOddsExplanation testCourseRepeatNavigationPersistenceAndGameIndependence testCourseWheelTaxonomyAndOverview; do
    set -- "$@" "-only-testing:PokerTrainerUITests/CriticalFlows/$QA_TEST"
  done
else
  set -- "-only-testing:PokerTrainerUITests/CriticalFlows/$QA_CASE"
fi
xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer -destination "platform=iOS Simulator,id=$QA_DEVICE" -derivedDataPath "$QA_DERIVED_DATA" -resultBundlePath "$QA_OUTPUT/flows.xcresult" -parallel-testing-enabled NO -collect-test-diagnostics never "$@" CODE_SIGNING_ALLOWED=NO test > "$QA_OUTPUT/flows.txt" 2>&1 || QA_EXIT=$?
xcrun xcresulttool get test-results summary --path "$QA_OUTPUT/flows.xcresult" > "$QA_OUTPUT/summary.json"
xcrun xcresulttool export attachments --path "$QA_OUTPUT/flows.xcresult" --output-path "$QA_OUTPUT/screenshots" > "$QA_OUTPUT/screenshots.txt" 2>&1
exit "$QA_EXIT"
