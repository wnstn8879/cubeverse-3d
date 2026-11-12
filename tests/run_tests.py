#!/usr/bin/env python3
"""Run headless tests, rejecting Godot script errors even if Godot exits zero."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
if not GODOT:
    sys.exit("Godot 4 is required")


def run(script: str, marker: str, *arguments: str) -> None:
    command = [GODOT, "--headless", "--path", str(ROOT), "--script", script]
    if arguments:
        command.extend(["--", *arguments])
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, env=environment, timeout=120)
    print(result.stdout, end="", flush=True)
    if result.returncode or re.search(r"(?:SCRIPT ERROR|^ERROR:)", result.stdout, re.MULTILINE) or marker not in result.stdout:
        sys.exit(f"Headless test failed: {script} {' '.join(arguments)}")


with tempfile.TemporaryDirectory(prefix="cubeverse-tests-") as directory:
    environment = dict(os.environ)
    environment["XDG_DATA_HOME"] = str(Path(directory) / "data")
    environment["XDG_CACHE_HOME"] = str(Path(directory) / "cache")
    run("res://tests/test_cube.gd", "CUBE_TEST_RESULT checks=1019 failures=0")
    run("res://tests/test_view.gd", "VIEW_GESTURES_PASS")
    run("res://tests/test_camera_drag.gd", "VIEW_CAMERA_DRAG_PASS checks=96")
    run("res://tests/test_regressions.gd", "APP_REGRESSIONS_PASS")
    run("res://tests/test_store_process.gd", "PROCESS_RESTART_WRITE_OK", "write")
    run("res://tests/test_store_process.gd", "PROCESS_RESTART_READ_OK", "read")
print("ALL_HEADLESS_TESTS_PASSED")
