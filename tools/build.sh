#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$TASK_ROOT/.tools/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$TASK_ROOT/.tools/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$TASK_ROOT/.tools/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" build/web build/android build/reports
touch build/.gdignore .tools/.gdignore
export GODOT_BIN="${GODOT_BIN:-godot}"
BUILD_TARGET="${1:-all}"
case "$BUILD_TARGET" in all|web|android) ;; *) echo "Usage: tools/build.sh [all|web|android]" >&2; exit 2 ;; esac
"$GODOT_BIN" --headless --path "$TASK_ROOT" --editor --import 2>&1 | tee build/reports/import.log
if rg -q 'SCRIPT ERROR|Parse Error|Failed to load script' build/reports/import.log; then
  exit 1
fi
rm -f build/reports/tests.passed build/reports/web.passed build/reports/android.passed
python3 tests/run_tests.py 2>&1 | tee build/reports/tests.log
python3 tools/test_app.py 2>&1 | tee build/reports/app-tests.log
if rg -q 'SCRIPT ERROR|Parse Error|Failed to load script' build/reports/tests.log; then
  exit 1
fi
touch build/reports/tests.passed
if [[ "$BUILD_TARGET" == web || "$BUILD_TARGET" == all ]]; then
  "$GODOT_BIN" --headless --path "$TASK_ROOT" --export-release Web build/web/index.html 2>&1 | tee build/reports/web-export.log
  test -s build/web/index.html
  test -s build/web/index.wasm
  test -s build/web/index.pck
  if rg -q 'SCRIPT ERROR|^ERROR:' build/reports/web-export.log; then exit 1; fi
  touch build/reports/web.passed
fi
if [[ "$BUILD_TARGET" == android || "$BUILD_TARGET" == all ]]; then
  python3 tools/configure_android.py
  "$GODOT_BIN" --headless --path "$TASK_ROOT" --export-debug Android build/android/CubeVerse-3D-debug.apk 2>&1 | tee build/reports/android-export.log
  test -s build/android/CubeVerse-3D-debug.apk
  if rg -q 'SCRIPT ERROR|^ERROR:' build/reports/android-export.log; then exit 1; fi
  python3 tools/verify_apk.py 2>&1 | tee build/reports/apk-verification.log
  touch build/reports/android.passed
fi
