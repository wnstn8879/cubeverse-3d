# 테스트 보고서

실행일: 2026-11-12 UTC. 환경: Linux 클라우드, Godot 4.6.3 stable. 실제 Android 기기에서 실행한 결과와 구분합니다.

## 자동 테스트 결과

프로젝트 리소스를 먼저 가져옵니다: `godot --headless --editor --import`.

명령: `python3 tests/run_tests.py`, `python3 tools/test_app.py`

```text
CUBE_TEST_RESULT checks=1019 failures=0
VIEW_GESTURES_PASS
VIEW_CAMERA_DRAG_PASS checks=96
APP_REGRESSIONS_PASS
PROCESS_RESTART_WRITE_OK
PROCESS_RESTART_READ_OK
ALL_HEADLESS_TESTS_PASSED
APP_TEST_RESULT checks=93 failures=0
APP_INTEGRATION_TESTS_PASSED
MOBILE_UI_TEST_RESULT checks=31 failures=0
MOBILE_UI_POINTER_TESTS_PASSED
```

| 검증 항목 | 결과 | 방법 |
| --- | --- | --- |
| 회전·역회전 후 원상 복원 | 통과 | 2×2~10×10, 세 축의 모든 층 |
| 같은 층 90도 4회·180도 2회 | 통과 | 정확한 정수 상태 키 비교 |
| 셔플의 유효성과 역순 복원 | 통과 | 크기별 80회 셔플, 합법 동작 이력 재생 |
| 완성 판정 | 통과 | 초기·단일 층 회전·전체 시점 회전·셔플 복원 |
| 실행 취소·다시 실행 | 통과 | 다중 이력·새 분기·저장 복원 후 재실행 |
| JSON 저장/불러오기 | 통과 | 모든 크기의 스티커·이력·앞으로 이력 비교 |
| 손상·불가능한 저장 상태 | 통과 | 슬롯 중복·잘못된 좌표/색/이력·체크섬 거절, 기존 상태 보존 |
| 원자적 저장과 백업 복구 | 통과 | 저장·설정 변경·손상된 주 파일의 이전 백업 복원 |
| 사운드 변경 후 설정 유지 | 통과 | 저장 객체 재생성과 별도 프로세스 read |
| 앱 프로세스 재실행 후 상태 | 통과 | 서로 다른 Godot 프로세스에서 10×10 상태·선택·사운드 복원 |
| 층 드래그·터치 취소 | 통과 | 합성 포인터 입력, 미리보기 중 논리 상태 불변과 취소 복원 |
| 두 번째 손가락·핀치 | 통과 | 미확정 회전 취소 및 확대 경로 |
| 카메라 각도별 드래그 일관성 | 통과 | 3×3·10×10, 8개 수평각·3개 수직각·2개 층 방향의 96개 사례 |
| 층 정렬·애니메이션 취소/다시 | 통과 | 드래그 놓기·트윈 완료·정수 상태 비교 |
| 배경 시점 회전·10×10 메시 | 통과 | 합성 입력 및 메시 생성 스모크 테스트 |

실행기는 Godot가 오류를 출력하고 종료 코드 0을 반환하는 경우도 실패로 처리합니다. 테스트별 성공 마커가 없으면 통과로 기록하지 않습니다.

## 빌드와 통합 검증

| 항목 | 상태 |
| --- | --- |
| Godot Web 내보내기 | 로컬 성공 · `build/reports/web-export.log`, `web.passed` |
| Android 디버그 APK | 로컬 빌드·ZIP 무결성·v2/v3 서명 통과 · `build/reports/android-export.log`, `apk-verification.log` |
| GitHub Actions 원격 실행 | 미실행 · 저장소 생성/접근 연결 대기 |
| Pages 공개 주소 접속 | 미실행 · 공개 배포 대기 |
| Linux 네이티브 화면 | 홈·10×10·설정 렌더링 확인 · `docs/home.png`, `docs/cube-10.png`, `docs/settings.png` |
| 실제 브라우저 플레이 | 미검증 · 이 세션에 브라우저 조작 도구가 제공되지 않음 |
| 아카데미·타이머·기록 전체 흐름 | 헤드리스 실제 앱 장면 통합 93개 검사 통과 · `build/reports/app-tests.log` |

앱 통합 검사는 화면 이동, 2×2·10×10·3×3별 상태 유지, 타이머 시작/종료와 기록, 두 학습 과정, 사운드·진도·기록 복원을 검증합니다. 별도 회귀 검사는 학습 중 자유 상태 보존, 잘못된 동작 취소, 회전 도중 학습 종료 방지, 화면 갱신 중 셔플 입력 잠금, 잘못된 저장 항목 처리를 검증합니다.

APK: `com.cubeverse.game`, 버전 `0.1.0-alpha`(코드 1), 최소 API 24·대상 API 36, `arm64-v8a`·`x86_64`, `VIBRATE` 권한만 선언했습니다. 산출물 크기 57,881,764바이트, SHA-256 `61c4a0f66b549cf7cf9dbe3cd48bf7e46bf1fbde2dc18b7f5766e697bafad9a5`입니다. 이 서명 검사는 실제 설치·실행을 증명하지 않습니다.

웹 산출물은 `index.wasm` 37,700,666바이트, `index.pck` 1,842,692바이트입니다. 내보내기 성공과 브라우저 실행 성공을 구분합니다.

## 미검증·제한

- 실제 Android 설치, 멀티터치 정확도, 진동 지원·강도·패턴, 실제 스피커/이어폰 청감.
- 모바일 60FPS, 입력 지연, 장시간 메모리·배터리, 오디오 동시 재생 부하.
- 모바일 Chrome·Safari 등 기기·브라우저별 WebGL/오디오/진동 지원.
- 실제 강제 종료·OS에 의한 앱 회수·브라우저 저장소 삭제 조건. 프로세스 재시작 테스트는 정상 저장 이후의 복원을 검증합니다.
- 온라인 검증·결제·특수 퍼즐은 미구현이므로 테스트 대상이 아닙니다.

10×10 메시 생성 시간은 클라우드 CPU 측정값일 뿐 모바일 FPS 증거가 아닙니다. 합성 입력 테스트는 실제 손가락 조작의 대체 검증으로 간주하지 않습니다.

정적 호스팅 어댑터 검증: WebAssembly·APK 분할 파일 재조합 SHA-256 일치, `WebAssembly.compileStreaming`, 엔진 캐시 및 일반 fetch 경로 검사를 Node에서 통과했습니다. 실제 브라우저 다운로드 UI 실행은 미검증입니다.

실제 `Input.parse_input_event` 터치 GUI 검증 31개 통과: 화면 이동·2×2 선택·사운드 저장·GUI 터치가 큐브를 돌리지 않음·원시 터치와 에뮬레이션 마우스가 중복 회전하지 않음. 물리 기기 이벤트 전달 자체의 검증은 아닙니다.
