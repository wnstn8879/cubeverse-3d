#!/usr/bin/env python3
"""Run real-scene integration checks with isolated local saves and strict logs.

Import the project before running this check (the build pipeline already does).
Headless testing validates coordinator behavior, not visual quality or device FPS.
"""

from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")


def main() -> int:
    if not GODOT:
        print("Godot 4 is required", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="cubeverse-app-tests-") as directory:
        environment = dict(os.environ)
        environment["XDG_DATA_HOME"] = str(Path(directory) / "data")
        environment["XDG_CACHE_HOME"] = str(Path(directory) / "cache")
        environment["XDG_CONFIG_HOME"] = str(Path(directory) / "config")
        command = [
            GODOT, "--headless", "--audio-driver", "Dummy",
            "--path", str(ROOT), "--script", "res://tests/test_app.gd",
        ]
        try:
            result = subprocess.run(
                command, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, env=environment, timeout=45,
            )
        except subprocess.TimeoutExpired as error:
            captured = error.stdout or b""
            if isinstance(captured, bytes):
                captured = captured.decode(errors="replace")
            print(captured, end="")
            print("Application integration checks exceeded 45 seconds", file=sys.stderr)
            return 1
        print(result.stdout, end="", flush=True)
        summary = re.search(r"APP_TEST_RESULT checks=(\d+) failures=(\d+)", result.stdout)
        errors = re.search(r"(?:SCRIPT ERROR|^ERROR:|Parse Error|Failed to load script)", result.stdout, re.MULTILINE)
        if result.returncode or errors or not summary or int(summary.group(1)) < 70 or int(summary.group(2)):
            print("Application integration checks failed", file=sys.stderr)
            return 1
    print("APP_INTEGRATION_TESTS_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
