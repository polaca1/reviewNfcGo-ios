import plistlib
import sys
from pathlib import Path

app = Path(sys.argv[1])
bundles = [
    (app, "reviewNfcGo", "com.pablo.resenagoogle.20261004"),
    (app / "PlugIns/reviewNfcGoLiveActivity.appex", "reviewNfcGoLiveActivity",
     "com.pablo.resenagoogle.20261004.liveactivity"),
]
for bundle, name, identifier in bundles:
    info = plistlib.loads((bundle / "Info.plist").read_bytes())
    assert info["CFBundleName"] == name
    assert info["CFBundleDisplayName"] == "reviewNfcGo"
    assert info["CFBundleIdentifier"] == identifier
    assert info["CFBundleShortVersionString"] == "2.9"
    assert info["CFBundleVersion"] == "10"
    assert info["DTPlatformName"] == "iphoneos"
    assert int(info["DTSDKName"].removeprefix("iphoneos").split(".")[0]) >= 26
    assert (bundle / info["CFBundleExecutable"]).stat().st_mode & 0o111
    assert not (bundle / "reviewNfcGo.debug.dylib").exists()
    print(bundle.name, "verified with", info["DTSDKName"])
assert plistlib.loads((app / "Info.plist").read_bytes())["NSSupportsLiveActivities"]
