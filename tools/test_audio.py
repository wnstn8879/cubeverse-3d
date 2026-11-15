#!/usr/bin/env python3
"""Validate original PCM and imported Godot playback with strict error handling.

Import project resources before this check, as tools/build.sh already does.
Dummy audio does not establish subjective ASMR quality or mobile latency.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        print("Godot 4 is required", file=sys.stderr)
        return 1
    asset_check = subprocess.run([sys.executable, str(ROOT / "tools/generate_audio.py"), "--check"], cwd=ROOT)
    if asset_check.returncode:
        return asset_check.returncode
    with tempfile.TemporaryDirectory(prefix="cubeverse-audio-tests-") as directory:
        environment = dict(os.environ)
        for name, folder in (("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")):
            environment[name] = str(Path(directory) / folder)
        try:
            result = subprocess.run(
                [godot, "--headless", "--audio-driver", "Dummy", "--path", str(ROOT), "--script", "res://tests/test_audio.gd"],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                env=environment, timeout=35,
            )
        except subprocess.TimeoutExpired as error:
            print(error.stdout or "")
            print("Audio integration exceeded 35 seconds", file=sys.stderr)
            return 1
        print(result.stdout, end="", flush=True)
        summary = re.search(r"AUDIO_TEST_RESULT checks=(\d+) failures=(\d+)", result.stdout)
        errors = re.search(r"(?:SCRIPT ERROR|^ERROR:|Parse Error|Failed to load script|ObjectDB instances leaked|resources still in use)", result.stdout, re.MULTILINE)
        if result.returncode or errors or not summary or int(summary.group(1)) < 500 or int(summary.group(2)):
            print("Audio integration checks failed", file=sys.stderr)
            return 1
    print("AUDIO_INTEGRATION_TESTS_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
