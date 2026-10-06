#!/bin/bash
set -euo pipefail
task_project_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$task_project_dir"
mkdir -p output build
xcodebuild -project reviewNfcGo.xcodeproj -scheme reviewNfcGo \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData -archivePath build/reviewNfcGo.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive > output/build-release.log 2>&1 || {
    tail -n 100 output/build-release.log
    exit 1
  }
task_app="$task_project_dir/build/reviewNfcGo.xcarchive/Products/Applications/reviewNfcGo.app"
python3 scripts/verify-app.py "$task_app"
task_stage=$(mktemp -d)
trap 'rm -rf "$task_stage"' EXIT
mkdir -p "$task_stage/Payload"
ditto "$task_app" "$task_stage/Payload/reviewNfcGo.app"
ditto -c -k --keepParent "$task_stage/Payload" "$task_project_dir/output/reviewNfcGo-2.9-Native-LiquidGlass.ipa"
python3 - <<'PY'
import zipfile
with zipfile.ZipFile('output/reviewNfcGo-2.9-Native-LiquidGlass.ipa') as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert 'Payload/reviewNfcGo.app/Info.plist' in names
    assert 'Payload/reviewNfcGo.app/PlugIns/reviewNfcGoLiveActivity.appex/Info.plist' in names
print('IPA verified: iPhone app and Live Activity extension included.')
PY
shasum -a 256 output/*.ipa > output/SHA256.txt
