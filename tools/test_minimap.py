#!/usr/bin/env python3
"""Verify face projections, input, camera switching and real variant meshes."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
if not godot:
    sys.exit("Godot 4 required")
with tempfile.TemporaryDirectory(prefix="cubeverse-map-test-") as tmp:
    env = dict(os.environ)
    for key, folder in (("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config"),("XDG_CACHE_HOME","cache")):
        env[key] = str(Path(tmp) / folder)
    result = subprocess.run([godot,"--headless","--audio-driver","Dummy","--path",str(root),"--script","res://tests/test_minimap.gd"], env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40)
    print(result.stdout,end="")
    marker = re.search(r"MINIMAP_VARIANT_RESULT checks=(\d+) failures=0",result.stdout)
    if result.returncode or not marker or re.search(r"SCRIPT ERROR|^ERROR:",result.stdout,re.M):
        sys.exit("Minimap / variant checks failed")
print("MINIMAP_VARIANT_TESTS_PASSED")
