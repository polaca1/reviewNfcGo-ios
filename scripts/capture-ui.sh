#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p output/screenshots
xcodebuild -project reviewNfcGo.xcodeproj -scheme reviewNfcGo \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Simulator CODE_SIGNING_ALLOWED=NO build \
  > output/build-simulator.log 2>&1 || { tail -n 100 output/build-simulator.log; exit 1; }
xcrun simctl list devices available --json > build/devices.json
task_device=$(python3 - <<'PY'
import json
devices = json.load(open('build/devices.json'))['devices']
choices = [(runtime, d) for runtime, ds in devices.items() for d in ds
           if ('iOS-26' in runtime or 'iOS-27' in runtime) and 'iPhone' in d['name']]
assert choices, 'An iOS 26+ simulator is required for native Liquid Glass.'
choices.sort(key=lambda item: (item[1]['name'] == 'iPhone 17', item[0]), reverse=True)
print(choices[0][1]['udid'])
PY
)
xcrun simctl boot "$task_device" || true
xcrun simctl bootstatus "$task_device" -b
xcrun simctl status_bar "$task_device" override --time '9:41' --batteryState charged --batteryLevel 100
xcrun simctl privacy "$task_device" grant location com.pablo.resenagoogle.20261004 || true
xcrun simctl install "$task_device" build/Simulator/Build/Products/Debug-iphonesimulator/reviewNfcGo.app
xcrun simctl ui "$task_device" appearance light
for task_screen in auth home history detail edit reminder earnings reminders profile; do
  xcrun simctl terminate "$task_device" com.pablo.resenagoogle.20261004 || true
  SIMCTL_CHILD_UI_REVIEW_SCREEN="$task_screen" xcrun simctl launch "$task_device" com.pablo.resenagoogle.20261004
  sleep 3
  xcrun simctl io "$task_device" screenshot "output/screenshots/$task_screen-light.png"
done
xcrun simctl ui "$task_device" appearance dark
for task_screen in auth history detail; do
  xcrun simctl terminate "$task_device" com.pablo.resenagoogle.20261004 || true
  SIMCTL_CHILD_UI_REVIEW_SCREEN="$task_screen" xcrun simctl launch "$task_device" com.pablo.resenagoogle.20261004
  sleep 3
  xcrun simctl io "$task_device" screenshot "output/screenshots/$task_screen-dark.png"
done
xcrun simctl shutdown "$task_device"
