#!/usr/bin/env python3
"""Check the tetrahedral minimap's physical slot colors and face input."""
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
with tempfile.TemporaryDirectory(prefix="cubeverse-pyra-map-") as tmp:
    env = dict(os.environ)
    for key, folder in (("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config"),("XDG_CACHE_HOME","cache")):
        env[key] = str(Path(tmp) / folder)
    result = subprocess.run([godot,"--headless","--audio-driver","Dummy","--path",str(root),"--script","res://tests/test_pyraminx_minimap.gd"], env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
    print(result.stdout,end="")
    if result.returncode or not re.search(r"PYRAMINX_MINIMAP_RESULT checks=\d+ failures=0",result.stdout) or re.search(r"SCRIPT ERROR|^ERROR:",result.stdout,re.M):
        sys.exit("Pyraminx minimap checks failed")
print("PYRAMINX_MINIMAP_TESTS_PASSED")
