# 개발 현황

기준: 0.2.0 통합 검증 세션. 작업 버전: **0.2.0 개발 알파**. 상용 출시 준비가 끝난 상태가 아닙니다.

## 이번 변경

- 무료 사운드를 6종에서 10종으로 확장했습니다. 말랑이·슬라임·크리미 폼·물방울 젤과 이벤트별 네 변형을 더해 240개 음원을 연결했습니다.
- 일반 큐브 여섯 면·피라밍크스 네 면 미니맵과 면 선택 카메라 이동을 추가했습니다.
- 3컬러 듀오의 보이는 색 기준 완성 판정, 쿠션·크리스털의 입체 메시, 네온 스타일과 스타일별 저장을 추가했습니다.
- 피라밍크스를 별도 120도 회전·팁 엔진으로 구현했습니다.
- 기존 네 동작 역회전 연습을 2×2·3×3·피라밍크스의 단계별 준비된 전체 풀이 예제로 교체했습니다. 학습 상태는 자유 플레이 저장과 분리합니다.
- GitHub 저장소 생성·접근과 기존 버전 보존 후, 검증된 0.2.0을 `main`, `develop`, `feature/asmr-academy-puzzles`에 반영했습니다. `v0.2.0-alpha` 태그와 공개 APK Release를 게시했습니다.

## 현재 검증·게시 상태

| 항목 | 확인된 결과 |
| --- | --- |
| NxN 엔진·저장·제스처 | 엔진 1,019개·카메라 96개, 회귀와 별도 프로세스 저장 복원 직전 실행 통과 |
| 앱 통합 | `APP_TEST_RESULT checks=345 failures=0` · 세 학습 과정·스타일·종류별 복원 통과 |
| 사운드 | 851개 검사 통과 · 240개 원본 WAV와 재생·미리 듣기·종료 정리 |
| 일반 미니맵·스타일 | 521개 검사 통과 |
| 피라밍크스 미니맵 | 148개 검사 통과 |
| 2×2·3×3 학습 | 409개 검사 통과 · 실제 상태 목표와 예제 전체 완성 |
| 피라밍크스 | 2,490개 검사 통과 · 상태·뷰·학습 |
| 실제 GUI 터치 통합 | 92개·실패 0 · 미니맵의 에뮬레이션 마우스 선행 중복 수정 확인 |
| 0.2.0 Web/APK | 전체 파이프라인·내보내기·APK 서명/내용 검증 통과 · `build/reports/final-manifest.json` |
| GitHub | 0.2.0 기능 `9716165`, 릴리스 태그 기준 `137ba9f` 저장 · main/develop/feature 반영 |
| GitHub Actions | [태그 실행](https://github.com/wnstn8879/cubeverse-3d/actions/runs/43675188530) 성공 · 전체 검사·Web/APK·Artifacts·Release |
| GitHub Pages | [main 빌드](https://github.com/wnstn8879/cubeverse-3d/actions/runs/43675188364) 성공, Pages 설정 생성 API 403으로 미게시 |
| APK Release | [v0.2.0-alpha](https://github.com/wnstn8879/cubeverse-3d/releases/tag/v0.2.0-alpha) 공개 게시 성공 |
| Sites | 0.2.0 비공개 웹·APK 다운로드·상태 페이지 게시 성공 |
| 실기기 | Android 설치·청감·진동·60FPS 미검증 |

모듈 검사와 전체 앱·터치·최종 빌드를 모두 통과했습니다. 최종 빌드 manifest 생성 시각은 `2026-11-15T03:56:11.303051+00:00`이며, 원격 게시와 실제 기기 검증은 별도로 확인합니다. 실패한 항목을 완료로 표시하지 않습니다. 학습 과정은 준비된 예제이며 임의 상태 풀이기는 미구현입니다.

## 다음 작업

1. [Pages 설정](https://github.com/wnstn8879/cubeverse-3d/settings/pages)에서 Source를 **GitHub Actions**로 활성화한 뒤 실패한 Pages 작업을 다시 실행해 실제 공개 웹 주소를 확인합니다. 현재 연결과 워크플로의 Pages 생성 API는 `Resource not accessible by integration`으로 거절됐습니다.
2. 통과한 0.2.0 로컬·Sites·공개 Release 산출물을 보존합니다. 다음 기능 변경은 별도 브랜치에서 해당 검사와 필요한 빌드를 통과시킨 뒤 통합합니다.
3. Android 실제 기기에서 설치·멀티터치·강제 종료 후 복원·청감·햅틱·성능을 확인합니다.
4. 준비된 학습 예제 이후의 임의 상태 가이드, 다른 실제 특수 퍼즐, 기록 리플레이와 출시 준비를 이어갑니다.

## 환경·현재 게시 인수인계

- 편집 프로젝트: `/workspace/cubeverse-3d`
- GitHub: https://github.com/wnstn8879/cubeverse-3d
- 비공개 웹: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site
- APK 페이지: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/downloads.html
- 게시 현황: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/status.html
- Sites project_id: `appgprj_6af5d70449908191b003fe9ace1bc88e`
- 0.2.0 성공 deployment_id: `appgdep_6af92e958b6c819188a60f133a29c482`
- 0.2.0 Sites 소스 커밋: `761b4627b7bbb9a636f2d8cb46a38558c8af8c9b`
- 기능 기준 커밋: `9716165c7910906d96362df352a6ffeeb5108385`
- GitHub 기능 CI 성공 실행: `43674662634`
- 태그 CI·Release 성공 실행: `43675188530`
- main 빌드 성공·Pages 실패 실행: `43675188364`
- 릴리스 태그 기준 커밋: `137ba9f003ed272a5ed37333c309649774d3e3cb`
- 공개 Release: https://github.com/wnstn8879/cubeverse-3d/releases/tag/v0.2.0-alpha
- 공개 APK: https://github.com/wnstn8879/cubeverse-3d/releases/download/v0.2.0-alpha/CubeVerse-3D-debug.apk
- 배포 전용 체크아웃: `/workspace/sites/cubeverse-play`

Sites 수정 시 기존 ID와 비공개 접근을 유지합니다. 단기 자격증명은 출력·파일·Git에 저장하지 않습니다. 호스팅 자산은 18MiB 조각으로 재구성하며, 소스 전송은 1회 64MiB 한도 이하의 여러 커밋으로 나눕니다. 전체 제품 완성도를 임의 백분율로 표시하지 않습니다.

## 0.2.0 최종 로컬 산출물

- APK: 59,200,397바이트 · SHA-256 `2afefe0fdec5569d8e63bfe1fc874521eebcb51eae862a030295a0ed80265138`
- Web PCK: 3,122,540바이트 · SHA-256 `09d7e3a472652ade5b61f4f8d509f6cc126957e3129ec378e8083ab4edd008b0`
- WASM: 37,700,666바이트 · SHA-256 `26b61ce95247012ab3dca3ff51e96d1cdbff44ee91a8c20a83e150afca83f1b6`
- 런타임 리소스 지문: `e1788e26085dbd5df94c91f9a3f4c12e1984d467d654df831ce1e6f639fdd70b`

## 공개 GitHub Release APK

- 태그: `v0.2.0-alpha` · 태그 CI와 Release 게시 성공
- 파일 크기: 59,200,397바이트
- SHA-256: `26900d3437e158c832986631ef11c1d4beabaa471c5fb05a05f54547dd263ff7`
- GitHub CI의 별도 디버그 서명으로 생성되어 위 로컬·Sites APK의 `2afefe…` 해시와 다릅니다. 같은 파일이라고 표시하지 않습니다.
