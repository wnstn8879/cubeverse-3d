# 개발 현황

기준: 0.2.0 통합 검증 세션. 작업 버전: **0.2.0 개발 알파**. 상용 출시 준비가 끝난 상태가 아닙니다.

## 이번 변경

- 무료 사운드를 6종에서 10종으로 확장했습니다. 말랑이·슬라임·크리미 폼·물방울 젤과 이벤트별 네 변형을 더해 240개 음원을 연결했습니다.
- 일반 큐브 여섯 면·피라밍크스 네 면 미니맵과 면 선택 카메라 이동을 추가했습니다.
- 3컬러 듀오의 보이는 색 기준 완성 판정, 쿠션·크리스털의 입체 메시, 네온 스타일과 스타일별 저장을 추가했습니다.
- 피라밍크스를 별도 120도 회전·팁 엔진으로 구현했습니다.
- 기존 네 동작 역회전 연습을 2×2·3×3·피라밍크스의 단계별 준비된 전체 풀이 예제로 교체했습니다. 학습 상태는 자유 플레이 저장과 분리합니다.
- GitHub 저장소 생성·접근이 확인됐고 기존 검증 버전 `787f2e5`를 `main`, `develop`, `feature/playable-foundation`에 푸시했습니다.

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
| GitHub | [저장소](https://github.com/wnstn8879/cubeverse-3d) 접근·기존 버전 푸시 완료 |
| GitHub Actions | [첫 실행](https://github.com/wnstn8879/cubeverse-3d/actions/runs/43566780587)의 SDK 설치 오류 확인·워크플로 수정, 새 실행 대기 |
| GitHub Pages | 설정 변경 API 403 · 사용자의 Source → GitHub Actions 설정 확인 필요 |
| Sites | 기존 0.1.0 비공개 게시본 유지 · 0.2.0 교체 대기 |
| 실기기 | Android 설치·청감·진동·60FPS 미검증 |

모듈 검사와 전체 앱·터치·최종 빌드를 모두 통과했습니다. 최종 빌드 manifest 생성 시각은 `2026-11-15T03:56:11.303051+00:00`이며, 원격 게시와 실제 기기 검증은 별도로 확인합니다. 실패한 항목을 완료로 표시하지 않습니다. 학습 과정은 준비된 예제이며 임의 상태 풀이기는 미구현입니다.

## 다음 작업

1. 미니맵 실제 GUI 터치 92개 통과 결과를 최종 빌드 검사에 포함하고 최신 앱·학습·저장 회귀를 확인합니다.
2. 통과한 0.2.0 최종 빌드를 보존합니다. 리소스가 바뀌면 해당 검사와 필요한 빌드를 다시 수행합니다.
3. 결과를 검토하고 `feature/asmr-academy-puzzles`에 커밋·푸시합니다. 검증 후 `develop`과 `main`에 반영합니다.
4. GitHub Actions 실제 로그·Artifacts·Pages·Release 결과를 확인합니다. Pages 권한 제한은 기존 Sites 미리보기 갱신과 별개로 처리합니다.
5. 최종 Web/APK를 기존 Sites에 게시하고 이 문서·README·TEST_REPORT의 버전·주소·커밋을 확정합니다.
6. Android 실제 기기에서 설치·멀티터치·강제 종료 후 복원·청감·햅틱·성능을 확인합니다.

## 환경·기존 게시 인수인계

- 편집 프로젝트: `/workspace/cubeverse-3d`
- GitHub: https://github.com/wnstn8879/cubeverse-3d
- 비공개 웹: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site
- APK 페이지: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/downloads.html
- 게시 현황: https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/status.html
- Sites project_id: `appgprj_6af5d70449908191b003fe9ace1bc88e`
- 기존 0.1.0 성공 deployment_id: `appgdep_6af5dac514bc8191ac9027fe9afce51c`
- 기존 Sites 소스 커밋: `3170b31c1b32dbf14acd6a30298ca61fc54b4722`
- 배포 전용 체크아웃: `/workspace/sites/cubeverse-play`

Sites 수정 시 기존 ID와 비공개 접근을 유지합니다. 단기 자격증명은 출력·파일·Git에 저장하지 않습니다. 호스팅 자산은 18MiB 조각으로 재구성하며, 소스 전송은 1회 64MiB 한도 이하의 여러 커밋으로 나눕니다. 전체 제품 완성도를 임의 백분율로 표시하지 않습니다.

## 0.2.0 최종 로컬 산출물

- APK: 59,200,397바이트 · SHA-256 `2afefe0fdec5569d8e63bfe1fc874521eebcb51eae862a030295a0ed80265138`
- Web PCK: 3,122,540바이트 · SHA-256 `09d7e3a472652ade5b61f4f8d509f6cc126957e3129ec378e8083ab4edd008b0`
- WASM: 37,700,666바이트 · SHA-256 `26b61ce95247012ab3dca3ff51e96d1cdbff44ee91a8c20a83e150afca83f1b6`
- 런타임 리소스 지문: `e1788e26085dbd5df94c91f9a3f4c12e1984d467d654df831ce1e6f639fdd70b`
