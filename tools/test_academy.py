#!/usr/bin/env python3
"""Run complete beginner-course checkpoint validation with strict Godot logs."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
if not godot:
    sys.exit("Godot 4 is required")
with tempfile.TemporaryDirectory(prefix="cubeverse-academy-") as directory:
    environment = dict(os.environ)
    for variable, folder in (("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")):
        environment[variable] = str(Path(directory) / folder)
    result = subprocess.run([godot, "--headless", "--audio-driver", "Dummy", "--path", str(ROOT), "--script", "res://tests/test_academy.gd"],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=environment, timeout=60)
    print(result.stdout, end="", flush=True)
    summary = re.search(r"ACADEMY_TEST_RESULT checks=(\d+) failures=(\d+)", result.stdout)
    if result.returncode or re.search(r"SCRIPT ERROR|^ERROR:|Parse Error", result.stdout, re.MULTILINE) or not summary or int(summary.group(2)) or int(summary.group(1)) < 250:
        sys.exit("Beginner academy validation failed")
print("BEGINNER_ACADEMY_TESTS_PASSED")
