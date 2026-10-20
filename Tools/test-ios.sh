#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"
QA_DEVICE=${1:-}
OWN_DEVICE=0
if [ -z "$QA_DEVICE" ]; then
  QA_DEVICE=$(xcrun simctl create 'Poker QA iPhone17e' com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-27-0)
  OWN_DEVICE=1
fi
# Fault injection is restricted to a dedicated QA simulator.
xcrun simctl list devices -j | python3 -c 'import json,sys; a=[d for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"]==sys.argv[1]]; assert len(a)==1 and a[0]["name"].startswith("Poker QA"), "Use a dedicated Poker QA simulator"' "$QA_DEVICE"
QA_OUTPUT="replica/tests/evidence/ios-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$QA_OUTPUT"
QA_RESTORE=0
restore_history() {
  if [ "$QA_RESTORE" != 1 ]; then return 0; fi
  # Installation by xcodebuild can replace the application data-container UUID.
  xcrun simctl boot "$QA_DEVICE" >/dev/null 2>&1 || :
  xcrun simctl bootstatus "$QA_DEVICE" -b >> "$QA_OUTPUT/boot.txt" 2>&1 || return 1
  QA_CONTAINER=$(xcrun simctl get_app_container "$QA_DEVICE" org.pokerpractice.native data) || return 1
  QA_HISTORY="$QA_CONTAINER/Library/Application Support/PokerPractice/practice-v1.json"
  mkdir -p "$(dirname -- "$QA_HISTORY")" || return 1
  cp "$QA_OUTPUT/history-before-fault.json" "$QA_HISTORY" || return 1
  cmp "$QA_OUTPUT/history-before-fault.json" "$QA_HISTORY" || return 1
  QA_RESTORE=0
}
cleanup() {
  restore_history || printf 'QA history restore failed; backup retained in %s\n' "$QA_OUTPUT" >&2
  if [ "$OWN_DEVICE" = 1 ]; then
    xcrun simctl shutdown "$QA_DEVICE" >/dev/null 2>&1 || :
    xcrun simctl delete "$QA_DEVICE" >/dev/null 2>&1 || :
  fi
}
trap cleanup EXIT
printf 'QA simulator: %s\nEvidence: %s\n' "$QA_DEVICE" "$QA_OUTPUT"
python3 Tools/prepare-offline-profile.py > "$QA_OUTPUT/compiled-network-profile.json"
QA_NETWORK_SINCE=$(date +%s)
xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer \
  -destination "platform=iOS Simulator,id=$QA_DEVICE" -derivedDataPath .build/ui-qa \
  -resultBundlePath "$QA_OUTPUT/flows.xcresult" -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -skip-testing:PokerTrainerUITests/CriticalFlows/testStorageFailureStillShowsPotOddsExplanation \
  CODE_SIGNING_ALLOWED=NO test > "$QA_OUTPUT/flows.txt" 2>&1
xcrun xcresulttool export attachments --path "$QA_OUTPUT/flows.xcresult" --output-path "$QA_OUTPUT/screenshots" --filter '*.png' > "$QA_OUTPUT/screenshots.txt"
# xcodebuild may shut the simulator down after completing its test session.
xcrun simctl boot "$QA_DEVICE" >/dev/null 2>&1 || :
xcrun simctl bootstatus "$QA_DEVICE" -b > "$QA_OUTPUT/boot.txt" 2>&1
python3 Tools/collect-offline-proof.py "$QA_DEVICE" "$QA_OUTPUT/network-proof" "$QA_NETWORK_SINCE" > "$QA_OUTPUT/network-proof.txt"
QA_CONTAINER=$(xcrun simctl get_app_container "$QA_DEVICE" org.pokerpractice.native data)
QA_HISTORY="$QA_CONTAINER/Library/Application Support/PokerPractice/practice-v1.json"
cp "$QA_HISTORY" "$QA_OUTPUT/history-before-fault.json"
QA_RESTORE=1
printf 'QA-corrupted-history-preserve-me' > "$QA_HISTORY"
QA_EXIT=0
xcodebuild -project PokerTrainer.xcodeproj -scheme PokerTrainer \
  -destination "platform=iOS Simulator,id=$QA_DEVICE" -derivedDataPath .build/ui-qa \
  -resultBundlePath "$QA_OUTPUT/save-failure.xcresult" -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -only-testing:PokerTrainerUITests/CriticalFlows/testStorageFailureStillShowsPotOddsExplanation \
  CODE_SIGNING_ALLOWED=NO test > "$QA_OUTPUT/save-failure.txt" 2>&1 || QA_EXIT=$?
# Preserve valid QA progress even when the fault-injection check fails.
restore_history
if [ "$QA_EXIT" != 0 ]; then exit "$QA_EXIT"; fi
xcrun xcresulttool export attachments --path "$QA_OUTPUT/save-failure.xcresult" --output-path "$QA_OUTPUT/save-failure-screenshots" --filter '*.png' > "$QA_OUTPUT/save-failure-screenshots.txt"
printf 'PASS: native flows and corrupt-history feedback. Evidence: %s\n' "$QA_OUTPUT"
