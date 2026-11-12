#!/usr/bin/env python3
"""Write machine-local Godot export settings; never commit keys or local paths."""
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
java = Path(os.environ.get("JAVA_HOME", str(root / ".tools/jdk17"))).resolve()
sdk = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", str(root / ".tools/android-sdk")))).resolve()
config = Path(os.environ.get("XDG_CONFIG_HOME", str(root / ".tools/config")))
key = root / ".tools/keys/debug.keystore"
key.parent.mkdir(parents=True, exist_ok=True)
if not (java / "bin/keytool").exists():
    raise SystemExit(f"JDK keytool missing: {java}; set JAVA_HOME to JDK 17")
if not (sdk / "platform-tools/adb").exists():
    raise SystemExit(f"Android platform-tools missing: {sdk}; install SDK or set ANDROID_HOME")
if not key.exists():
    subprocess.run([str(java / "bin/keytool"), "-genkeypair", "-keystore", str(key), "-storepass", "android", "-alias", "androiddebugkey", "-keypass", "android", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000", "-dname", "CN=CubeVerse Debug,O=CubeVerse,C=KR"], check=True)
settings = config / "godot/editor_settings-4.6.tres"
settings.parent.mkdir(parents=True, exist_ok=True)
settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' + '\n'.join(f'{name}={json.dumps(str(value))}' for name, value in {
    "export/android/java_sdk_path": java,
    "export/android/android_sdk_path": sdk,
    "export/android/debug_keystore": key,
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
}.items()) + '\n')
print("Configured Android export with a local debug key (not a production signing key).")
