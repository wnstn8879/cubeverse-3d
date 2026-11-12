#!/usr/bin/env python3
"""Publish measured build checks beside the web export, never a roadmap guess."""
import datetime
import html
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
out = root / "build/web"
out.mkdir(parents=True, exist_ok=True)
try:
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
except subprocess.CalledProcessError:
    commit = "local-uncommitted"
checks = []
for title, marker in (("큐브 엔진 자동 테스트", "build/reports/tests.passed"), ("Godot Web 내보내기", "build/reports/web.passed"), ("Android 디버그 APK 빌드", "build/reports/android.passed")):
    path = root / marker
    checks.append({"name": title, "passed": path.exists()})
repo = os.environ.get("GITHUB_REPOSITORY", "")
run = os.environ.get("GITHUB_RUN_ID", "")
url = f"https://github.com/{repo}/actions/runs/{run}" if repo and run else ""
data = {"commit": commit, "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "checks": checks, "actions_run_url": url, "limitations": ["Android 실기기 성능·햅틱 검증 대기", "온라인 대전·로그인·결제 미구현"]}
(out / "status.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
rows = "".join(f'<li>{"✓" if c["passed"] else "대기"} · {html.escape(c["name"])}</li>' for c in checks)
run_link = f'<a href="{html.escape(url)}">GitHub Actions 실행 및 APK 아티팩트</a>' if url else '<p>로컬 빌드입니다. GitHub Actions 실행 결과는 아직 없습니다.</p>'
(out / "status.html").write_text(f'''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>CubeVerse 3D · 빌드 현황</title><style>body{{margin:0;background:#0b1020;color:#eaf1ff;font:17px/1.8 system-ui,sans-serif;padding:32px;max-width:780px}}a{{color:#70e9c3}}li{{margin:12px 0}}code{{overflow-wrap:anywhere;color:#b7c7e0}}</style><h1>CubeVerse 3D</h1><p>이 배포에 포함된 빌드 검사 {sum(c["passed"] for c in checks)}/{len(checks)}개 통과</p><ul>{rows}</ul><p>커밋 <code>{html.escape(commit)}</code><br>생성 시각 {html.escape(data["generated_utc"])}</p>{run_link}<p>Android 실기기 성능·햅틱은 아직 검증하지 않았습니다. 온라인 대전·로그인·결제는 개발 예정입니다.</p><a href="index.html">게임 열기 →</a></html>''')
print("Generated web build status for", commit)
