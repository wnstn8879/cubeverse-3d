# 개발 현황

기준일: 2026-11-12 UTC. 버전: 0.1.0 개발 알파. 상용 출시 완료 상태가 아닙니다.

## 이번 세션 결과

- Godot 4.6.3 기반 프로젝트와 실제 3D 회전 엔진을 생성했습니다.
- 2×2~10×10의 상태·셔플·취소/다시·저장을 자동 검증했습니다.
- 합성 터치로 층 미리보기·취소·핀치 전환·정렬, 배경 시점 회전, 애니메이션 취소/다시를 검증했습니다.
- 6종 무료 합성 음원과 한국어 UI, 고정 예제 학습, 오프라인 기록 코드를 연결했습니다.
- 테스트·웹 내보내기·디버그 APK·Pages·사전 릴리스의 Actions 워크플로를 작성했습니다.

## 검증·배포 상태

| 항목 | 상태와 증거 |
| --- | --- |
| 엔진·저장 | `python3 tests/run_tests.py` · 엔진 1,019개 검사, 실패 0 |
| 제스처 | 같은 실행기의 `VIEW_GESTURES_PASS` · 합성 입력 검증 |
| 재실행 | 별도 Godot 프로세스 write/read에서 10×10 상태·사운드·선택 복원 |
| 앱 통합 | `python3 tools/test_app.py` · 93개 검사, 실패 0 |
| 회귀 검증 | 학습 중 자유 상태 보존·잘못된 동작 취소·회전 중 종료 방지·셔플 중 화면 갱신 입력 잠금 통과 |
| 웹 | Web 내보내기 및 [비공개 Sites 게시](https://cubeverse-3d-play.angksehdfur2468.chatgpt.site) 성공 |
| APK | 디버그 APK 빌드·ZIP 무결성·v2/v3 서명 통과 · `build/reports/apk-verification.log` |
| GitHub | 계정·CLI 인증 확인, 저장소 생성이 연결 통합의 권한 부족으로 거절되어 원격 게시 대기 |
| 기능 기준 커밋 | `cdfd21362d8887a5b99cc330fd3703677261e133` · 로컬 Git 보존, GitHub 푸시 대기 |
| 화면 확인 | Linux 네이티브 홈·10×10·설정 렌더링 확인 · `docs/*.png` |
| 웹 브라우저 실행 | 미검증 · 이 세션에 브라우저 조작 도구가 제공되지 않음 |
| 실제 모바일 | Android 설치·60FPS·터치·햅틱 미검증 |

## 단계별 판정

Phase 0의 로컬 웹·APK 빌드와 비공개 웹·APK 다운로드 게시가 완료됐습니다. GitHub 저장소 연결, 원격 Actions·Pages·Releases 실행은 남아 있습니다. Phase 1~3의 기본 구현과 엔진 검증을 진행했고, 실제 모바일 품질 검증은 남아 있습니다. Phase 4는 제한된 역회전 연습과 로컬 타이머 범위입니다. Phase 5~7의 온라인·결제·상용 출시 작업은 완료되지 않았습니다.

## 다음 세션 시작점

1. 기존 로컬 작업과 문서를 보존하고 `python3 tests/run_tests.py`부터 실행합니다.
2. `cubeverse-3d` GitHub 저장소 생성과 쓰기/워크플로 권한을 확인합니다. 비밀 토큰은 채팅이나 Git에 기록하지 않습니다.
3. 이 세션에는 CLI 인증이 확인되었지만 저장소 생성 API가 연결 통합의 권한 부족으로 거절되었습니다. 사용자가 저장소를 만든 뒤 연결 대상에 포함하면 재시도합니다.
4. `feature/*`에서 변경 검토·커밋, `develop` 통합을 수행합니다. `main`은 테스트와 필요한 빌드가 통과한 상태만 반영합니다.
5. Actions를 실행하고 Pages 실제 URL과 APK Artifacts/Release URL을 README에 확정 기록합니다.
6. Android 실기기에서 설치·조작·강제 종료 후 복원·오디오·햅틱을 검증합니다.
7. 타이머·학습·기록 통합 회귀 검증 후 상태별 학습과 기록 리플레이를 확장합니다.

작업 중단 후에도 이 파일과 TEST_REPORT.md의 실제 증거를 기준으로 이어갑니다. 원격 게시·기기 테스트가 없는 항목을 완료로 올리지 않습니다.

## 게시 확정 및 인수인계

- 웹: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site
- APK 다운로드: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/downloads.html
- 현황: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/status.html
- Sites project_id: `appgprj_6af5d70449908191b003fe9ace1bc88e`
- 성공 deployment_id: `appgdep_6af5dac514bc8191ac9027fe9afce51c`
- Sites 배포 소스 커밋: `3170b31c1b32dbf14acd6a30298ca61fc54b4722`
- 편집 가능한 게임 프로젝트: `/workspace/cubeverse-3d`, 배포 전용 체크아웃: `/workspace/sites/cubeverse-play`
- GitHub 저장소가 제공되면 로컬 `main`, `develop`, `feature/playable-foundation`을 푸시하고 Actions 실제 결과를 확인합니다. 현재 원격에 작업이 저장됐다고 표시하지 않습니다.
- Sites 수정 시 기존 `.openai/hosting.json`의 ID와 비공개 접근을 보존합니다. Sites를 새로 생성하지 않습니다. 자격증명은 매번 연결 도구에서 단기 발급하고 출력·파일·Git에 저장하지 않습니다.
- 원격 소스 업로드 한도는 1회 64MiB라 Web과 APK를 별도 커밋으로 전송했습니다. 호스팅 자산은 18MiB 조각으로 재구성하며 SHA-256 및 WASM 컴파일 검증을 통과했습니다.
