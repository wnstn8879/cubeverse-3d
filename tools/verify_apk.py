#!/usr/bin/env python3
"""Reject unsigned, corrupt or unexpected APKs before artifact publication."""
import os
from pathlib import Path
import re
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
sdk = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", str(root / ".tools/android-sdk"))))
apk = root / "build/android/CubeVerse-3D-debug.apk"
versions = sorted((sdk / "build-tools").glob("*/apksigner"), key=lambda p: tuple(int(x) for x in re.findall(r"\d+", p.parent.name)), reverse=True)
if not versions:
    raise SystemExit("No apksigner found; cannot verify APK")
subprocess.run([str(versions[0]), "verify", "--verbose", str(apk)], check=True)
with zipfile.ZipFile(apk) as archive:
    if archive.testzip() is not None:
        raise SystemExit("Corrupt APK ZIP entry")
    names = set(archive.namelist())
    for path in ("AndroidManifest.xml", "lib/arm64-v8a/libgodot_android.so", "lib/x86_64/libgodot_android.so"):
        if path not in names:
            raise SystemExit("APK is missing " + path)
aapt = versions[0].parent / "aapt"
if aapt.exists():
    metadata = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True)
    if "name='com.cubeverse.game'" not in metadata or "sdkVersion:'24'" not in metadata:
        raise SystemExit("Unexpected package identity or minimum SDK")
    for line in metadata.splitlines():
        if line.startswith(("package:", "sdkVersion:", "targetSdkVersion:", "uses-permission:", "application-label:", "native-code:")):
            print(line)
print("APK_SIGNATURE_AND_CONTENT_VERIFIED")
