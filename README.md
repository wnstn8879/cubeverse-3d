# CubeVerse 3D

손끝으로 층을 돌리고 소리와 함께 즐기는 모바일 3D 큐브 게임입니다. **0.2.0 개발 알파**이며, Godot 4.6.3 / GDScript / Compatibility 렌더러를 사용합니다.

## 실행·배포 상태

| 항목 | 확인된 상태 |
| --- | --- |
| 소스 저장소 | [wnstn8879/cubeverse-3d](https://github.com/wnstn8879/cubeverse-3d) · 기존 검증 버전 푸시 완료 |
| 웹 플레이 | [비공개 웹 미리보기](https://cubeverse-3d-play.angksehdfur2468.chatgpt.site) · 현재 게시본은 0.1.0, 0.2.0 갱신 준비 중 |
| APK 다운로드 | [테스트 APK 페이지](https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/downloads.html) · 현재 게시본은 0.1.0 |
| 자동 빌드 | [GitHub Actions](https://github.com/wnstn8879/cubeverse-3d/actions) · 첫 실행의 SDK 설치 오류 수정 후 재검증 대기 |
| GitHub Pages | 설정 변경 API 권한이 없어 Source → GitHub Actions 활성화 확인 필요 |
| 최신 0.2.0 | 모든 로컬 검사·Web/APK 내보내기·APK 서명 검증 통과, 원격 게시 준비 중 |
| 실제 Android | 설치·기기 터치·햅틱·성능 미검증 |

비공개 미리보기는 본인 ChatGPT 계정으로 접근합니다. [배포 빌드 현황](https://cubeverse-3d-play.angksehdfur2468.chatgpt.site/status.html)은 해당 게시본의 코드와 빌드 결과를 표시합니다. 저장소의 작업 버전과 게시본은 같지 않을 수 있습니다. 최종 결과는 [TEST_REPORT.md](TEST_REPORT.md)와 [DEPLOYMENT.md](DEPLOYMENT.md)를 확인하세요.

## 0.2.0에서 추가한 기능

- **말랑한 ASMR 사운드**: 말랑이·슬라임 스트레치·크리미 폼·물방울 젤을 더해 무료 10종, 이벤트 6종, 변형 샘플 240개를 제공합니다. 직전 샘플 반복을 피하고 속도에 따라 음색을 바꾸며, 미리 듣기는 누름→마찰→놓기 흐름을 재생합니다. 직접 합성한 음원이며 실제 기기 청감은 검증 전입니다.
- **전체 면 미니맵**: 일반 큐브의 여섯 면과 피라밍크스의 네 면을 실제 상태에서 표시합니다. 가려진 면을 확인하고 면을 눌러 시점을 옮길 수 있습니다. 학습에서는 다음 회전 면을 강조합니다.
- **색다른 큐브**: 마주 보는 면이 같은 색인 3컬러 듀오, 볼록한 쿠션 메시, 모서리를 깎은 크리스털 메시, 네온 스타일을 추가했습니다. 각 스타일의 진행 상태를 따로 저장합니다. 이 모양 스타일은 일반 NxN 회전 규칙을 사용합니다.
- **피라밍크스**: 별도 정사면체 상태 엔진으로 120도 큰 층 회전과 독립 꼭짓점 회전, 셔플, 취소·다시 실행, 저장 복원을 구현했습니다.
- **처음부터 배우는 아카데미**: 조각과 표기법을 설명한 뒤, 한국어 목표·관찰 지점·동작별 목적과 시범을 제공합니다. 3×3은 데이지→아래 흰 십자가→첫 층→가운데 층→노란 십자가→노란 면→마지막 교환, 2×2는 흰 층→노란 면→코너 교환, 피라밍크스는 팁→중앙→엣지 순서입니다.

학습은 **예제로 준비된 퍼즐을 끝까지 완성하는 과정**입니다. 자유 플레이 상태를 보존하고 단계 재시작과 잘못된 동작 복원을 지원합니다. 임의로 섞인 모든 상태의 풀이를 자동 판별하는 해법 엔진은 아직 없습니다.

## 기본 기능

2×2~10×10 공통 정수 상태 엔진, 조각 드래그와 층 미리보기·정렬, 배경 드래그 시점 이동, 핀치 확대, 셔플, 완성 판정, 실행 취소·다시 실행, 퍼즐별 자동 저장과 백업 복구를 제공합니다. 한국어 다크 UI에서 자유 플레이와 로컬 타이머·기록을 사용할 수 있습니다. Android 진동과 웹 진동 API 지원을 감지하며, 기기별 동작은 실기기 검증 전입니다.

## 남은 기능

진짜 미러 큐브·메가밍크스·스큐브·기어·스퀘어-1·피셔·고스트의 개별 엔진, 임의 상태 풀이와 상태별 화살표, 리플레이 화면·통계, 영어 UI, 로그인·클라우드 동기화, 친구·온라인 대전·서버 검증·랭킹, 프리미엄 상품·Google Play 결제·구매 복원, 정식 서명과 Play 등록은 미구현입니다. 결제되지 않은 상품을 구매 완료로 표시하지 않습니다.

검증된 0.2.0 APK는 현재 로컬 `build/android/CubeVerse-3D-debug.apk`에 있습니다. 웹 다운로드 페이지의 0.2.0 교체와 GitHub Release 주소는 게시 성공 후 확정합니다.

## 개발 실행

Godot 4.6.3에서 `project.godot`을 열고 실행합니다. 전체 검사는 공식 내보내기 템플릿, Python 3, JDK 17과 Android SDK가 필요합니다.

```sh
godot --path .
python3 tools/install_templates.py
tools/build.sh all
python3 tools/write_build_status.py
```

빌드 스크립트는 리소스 가져오기, 엔진·앱·터치·사운드·미니맵·학습·피라밍크스 검사 후 Web과 디버그 APK를 내보냅니다. 로컬 APK 경로는 `build/android/CubeVerse-3D-debug.apk`, Web 경로는 `build/web/index.html`입니다. Android 7.0(API 24) 이상, arm64-v8a 또는 x86_64를 대상으로 하며 디버그 서명은 정식 출시용이 아닙니다.

로컬 웹은 `file://` 대신 HTTP로 제공합니다.

```sh
python3 -m http.server 8765 --directory build/web
```

## 프로젝트 구성

| 경로 | 역할 |
| --- | --- |
| `scripts/core/` | NxN 상태·저장·스타일별 완성 기준 |
| `scripts/puzzles/` | 별도 피라밍크스 상태와 준비된 학습 과정 |
| `scripts/academy/` | 2×2·3×3 학습 단계와 목표 판정 |
| `scripts/view/` | 3D 메시·카메라·입력·미니맵 |
| `scripts/audio/` | 사전 로드 효과음·미리 듣기·햅틱 |
| `scripts/ui/` | 화면·학습·로컬 기록 연결 |
| `tests/`, `tools/`, `.github/workflows/` | 자동 검증·빌드·배포 |

진행 상태는 [PROGRESS.md](PROGRESS.md), 계획은 [ROADMAP.md](ROADMAP.md), 변경 사항은 [CHANGELOG.md](CHANGELOG.md)에 기록합니다. 오디오 조건은 [AUDIO_LICENSE.md](AUDIO_LICENSE.md), 폰트 조건은 `assets/fonts/LICENSE.txt`를 참고하세요.
